#function to sample from a Gaussian mixture model
rbilnorm <- function(N, mu1, mu2, sigma1, sigma2, tau){
  ind <- I(runif(N) > tau)
  X <- rep(0,N)
  X[ind] <- rlnorm(sum(ind), mu1, sigma1)
  X[!ind] <- rlnorm(sum(!ind), mu2, sigma2)
  return(X)
}

#pdf from the Gaussian mixture model

dbilnorm <- function(x, mu1, mu2, sigma1, sigma2, tau){
  y <- (1-tau)*dlnorm(x, mu1, sigma1) + tau * dlnorm(x, mu2, sigma2)
  return(y)
}

#EM algorithm for GMMM
EM = function(x, mu1, mu2, sigma1, sigma2, tau) {
  n = length(x)
  lold = 0
  lnew = 10
  while (abs(lold-lnew) > 10^-2) {
    #calculate log likelihood for convergence criteria
    lold = sum(log((1 - tau)*dlnorm(x, mean = mu1, sd = sigma1) + tau * dlnorm(x, mean = mu2, sd = sigma2)))
    p = dlnorm(x, mean = mu2, sd = sigma2) * tau / dbilnorm(x, mu1, mu2, sigma1, sigma2, tau)
    #update the parameters according to ML estimator of slide 15, week 7
    tau = 1/n * sum(p)
    mu1 = sum(log(x) * (1 - p)) / sum(1 - p)
    mu2 = sum(log(x) * p) / sum(p)
    sigma1 = sqrt(sum((1 - p) * ((log(x) - mu1)^2)) / sum(1 - p))
    sigma2 = sqrt(sum(p * ((log(x) - mu2)^2)) / sum(p))
    #calculate log likelihood for convergence criteria
    lnew = sum(log((1 - tau)*dlnorm(x, mean = mu1, sd = sigma1) + tau * dlnorm(x, mean = mu2, sd = sigma2)))
  }
  return(c(mu1, mu2, sigma1, sigma2, tau))
}

data = snowdata
num_inbin = length(data$X)
num_part = data$particles.detected[1]
for (i in 1:length(data$X)) {
  num_inbin[i] = round(data$retained....[i] / 100 * num_part)
}
#jitter the data
n = sum(num_inbin)
counter = 0
jittered_data = rep(0, n)
data$endpoint[52] = 3.25 
for (i in 1:length(num_inbin)) {
  interval_length = data$endpoint[i] - data$startpoint[i]
  for(j in 1:num_inbin[i]) {
    if (num_inbin[i] == 0) {
      next
    }
    jittered_data[j + counter] = data$startpoint[i] + 
      runif(1, min = 0, max = interval_length)
  }
  counter = counter + num_inbin[i]
}
breaks = seq(from = 0, to = 3, by = 0.01)
hist(jittered_data, breaks=1000) # histogram of jittered data
#barplot(height = data$retained...., width = width) # histogram with bins of the data
mu1 <- -3
mu2 <- -0.5
sigma1 <- 0.3
sigma2 <- 0.4
tau <- 0.7
estim = EM(jittered_data, mu1, mu2, sigma1, sigma2, tau)
print(estim)

#optimization 
#write log likelihood function of binned data
cdfbilognorm = function(x, mu1, mu2, sigma1, sigma2, tau) {
  y <- (1 - tau) * plnorm(x, mu1, sigma1) + tau * plnorm(x, mu2, sigma2)
  return(y)
}

negloglikelihood = function(par) {
  logli = 0
  mu1 = par[1]
  mu2 = par[2]
  sigma1 = par[3]
  sigma2 = par[4]
  tau = par[5]
  for (i in 1:length(data$X)) {
    logli = logli + (num_inbin[i]) * log((cdfbilognorm(data$endpoint[i], mu1, mu2, sigma1, sigma2, tau) - 
                       cdfbilognorm(data$startpoint[i], mu1, mu2, sigma1, sigma2, tau)))
  }
  return(-logli)
}
out = optim(estim, negloglikelihood)
estim_opt = as.numeric(unlist(out[1]))
mu1_opt = estim_opt[1]
mu2_opt = estim_opt[2]
sigma1_opt = estim_opt[3]
sigma2_opt = estim_opt[4]
tau_opt = estim_opt[5]
x_grid = seq(from = 0, to = 3, by = 0.01)
pdf_est = dbilnorm(x_grid, mu1_opt, mu2_opt, sigma1_opt, sigma2_opt, tau_opt)
jittered_pdf = density(x = jittered_data)
plot(jittered_pdf)
lines(x_grid, pdf_est, col = "red")


width = rep(0, length(data$X))
for (i in 1:length(data$X)) {
  width[i] = data$endpoint[i] - data$startpoint[i]
}

# bootstrap
n_bootstrap = 5 # number of bootstrap samples
ndata_boot = 500 # number of data in bootstrap sample
bootstrap_data = matrix(nrow = ndata_boot, ncol = n_bootstrap) 
for (i in 1:n_bootstrap) {
  set.seed(i) # different seed for each bootstrap data
  bootstrap_data[, i] = rbilnorm(ndata_boot, mu1_opt, mu2_opt, sigma1_opt, sigma2_opt, tau_opt)
}
#bin the bootstrap data
binned_bootstrap_data = matrix(nrow = length(data$X), ncol = n_bootstrap)
for (i in 1:n_bootstrap) {
  for (j in 1:length(data$X)) {
    counter = 0
    for (k in 1:ndata_boot) {
      if (data$startpoint[j] <= bootstrap_data[k, i] && data$endpoint[j] > bootstrap_data[k, i]) {
        counter = counter + 1
      }
    }
    binned_bootstrap_data[j, i] = counter # number of data points in j-th bin
  }
}

# jitter the binned bootstrap samples
jittered_boot_data = matrix(nrow = ndata_boot, ncol = n_bootstrap)
for (k in 1:n_bootstrap) {
  counter = 0
  for (i in 1:length(data$X)) {
    interval_length = data$endpoint[i] - data$startpoint[i]
    for(j in 1:binned_bootstrap_data[i, k]) {
      if (binned_bootstrap_data[i, k] == 0) {
        next
      }
      jittered_boot_data[j + counter, k] = data$startpoint[i] + 
        runif(1, min = 0, max = interval_length)
    }
    counter = counter + binned_bootstrap_data[i, k]
  }
}

#estimate the parameters for each bootstrap sample
estim_boot = matrix(nrow = 5, ncol = n_bootstrap)
for (i in 1:n_bootstrap) {
  estim_boot[, i] = EM(jittered_boot_data[, i], mu1, mu2, sigma1, sigma2, tau)
}
estim_boot_opt = matrix(nrow = 5, ncol = n_bootstrap)
for (i in 1:n_bootstrap) {
  out = optim(estim_boot[, i], negloglikelihood)
  estim_boot_opt[, i] = as.numeric(unlist(out[1]))
}
 
#Calculate the kolmogorov smirnoff statisitc
#create data to use for ecdf for binned data

ecdf_binned = cumsum(snowdata$retained....)/100
kol_smir = 0 
for (i in 1:nrow(snowdata)) {
  a = abs(ecdf_binned[i] - 
            cdfbilognorm(snowdata$endpoint[i], mu1_opt, mu2_opt, sigma1_opt, sigma2_opt, tau_opt))
  if (a > kol_smir) {
    kol_smir = a
    print(cdfbilognorm(snowdata$endpoint[i], mu1_opt, mu2_opt, sigma1_opt, sigma2_opt, tau_opt))
  }
}

#calculate T_b^*
T_b = rep(0, n_bootstrap)
for (k in 1:n_bootstrap) {
  counter = 0
  ecdf_boot_data = rep(0, ndata_boot)
  for (i in 1:length(data$X)) {
    interval_length = data$endpoint[i] - data$startpoint[i]
    for(j in 1:binned_bootstrap_data[i, k]) {
      if (binned_bootstrap_data[i, k] == 0) {
        next
      }
      ecdf_boot_data[j + counter] = data$startpoint[i] + interval_length / j
    }
    counter = counter + binned_bootstrap_data[i, k]
  }
  ecdf_boot = ecdf(ecdf_boot_data)
  for (j in 1:length(x_grid)) {
    a = abs(ecdf_boot(x_grid[j]) - 
              cdfbilognorm(x_grid[j], estim_boot_opt[1, k], estim_boot_opt[2, k], 
                           estim_boot_opt[3, k], estim_boot_opt[4, k], estim_boot_opt[5, k]))
    if (a > T_b[k]) {
      T_b[k] = a
    }
  }
}

#calculate the estimated p value
a = 0
for (k in 1:n_bootstrap) {
  if (T_b[k] > kol_smir) {
    a = a + 1
  }
}
p = 1 / (n_bootstrap + 1) * (a + 1)
print(p)
