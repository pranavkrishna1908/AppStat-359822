snowdata <- read.csv("E:/EPFL/AppStat/AppStat-359822/Project-Snowflakes/1_snow_particles.csv")
set.seed(0)
str(snowdata)
summary(snowdata)
library(ggplot2)


jitter_function= function(snowdata2 = snowdata){
  jittereddataset = rep(0, 1)
  counter = 1
  increment = 0
  num_loop = which(snowdata2$retained.... == 0)[1] - 1
  for(i in 1:num_loop){
    increment = as.integer(snowdata2$retained....[i]*snowdata2$particles.detected[i]/100)
    jittereddataset[counter:(counter+increment)] =   runif(increment, min = snowdata2$startpoint[i], max = snowdata2$endpoint[i])
    counter = counter + increment
  }
  return(jittereddataset)
}
plot = ggplot()+
  geom_histogram(mapping = aes(x = jitter_function(), y = ..density..), breaks = c(snowdata$endpoint[1:47], 0))+
  xlab('Snowflake Diameters')+
  ylab('Density')
plot




#jitter and em
#jittered data set construction
dmixlnorm <- function(x, mu1, mu2, sigma1, sigma2, tau){
  y <- (1-tau)*dlnorm(x,mu1,sigma1) + tau*dlnorm(x,mu2,sigma2)
  return(y)
}
pmixlnorm <- function(x, mu1, mu2, sigma1, sigma2, tau){
  y <- (1-tau)*plnorm(x,mu1,sigma1) + tau*plnorm(x,mu2,sigma2)
  return(y)
}
rmixlnorm <- function(n, mu1, mu2, sigma1, sigma2, tau){
  unifs = runif(n)
  indicators = unifs<0.5
  answer = indicators*rlnorm(n, mu1, sigma1) + (1 - indicators)*rlnorm(n, mu2, sigma2)
  return(answer)
}
likelihood <- function(x, mu1, mu2, sigma1, sigma2, tau){
  temp = 0
  for (i in 1:length(x)) {
    temp = temp + log(dmixlnorm(x[i], mu1,mu2,sigma1, sigma2, tau))
  }
  return(temp)
}
reallikelihood = function( params){
  mu1 = params[1]
  mu2 = params[2]
  sigma1 = exp(params[3])
  sigma2 = exp(params[4])
  tau = 1/(1 + exp(params[5]))
  temp = 0
  snowdata3 = snowdata
  snowdata3$number = as.integer(snowdata3$retained....*snowdata3$particles.detected/100)
  for(i in 1:nrow(snowdata3)){
    temp = temp +snowdata3[i,6] * log(pmixlnorm(snowdata3[i,3],mu1, mu2, sigma1, sigma2, tau) - pmixlnorm(snowdata3[i,2], mu1, mu2, sigma1, sigma2, tau))
  }
  return(-temp)
}


em_function = function(snowdata2 = snowdata){
  sample = jitter_function(snowdata2)
  N = length(sample)
  mu1 = 10
  mu2 = 20
  sigma1_sq = 100
  sigma2_sq = 1000
  tau = 0.9999
  likelihood_obs = likelihood(sample,  mu1, mu2, sigma1_sq, sigma2_sq, tau)
  p = rep(0, N)
  piece1 = dlnorm(sample ,mean = mu2, sd = sqrt(sigma2_sq))*tau
  piece2 = dmixlnorm(sample, mu1, mu2, sqrt(sigma1_sq), sqrt(sigma2_sq), tau)
  p = piece1/piece2
  next_tau = sum(p)/N
  next_mu1 = (sum((1-p)*log(sample)))/(N - sum(p))
  next_mu2 = sum(p*log(sample))/sum(p)
  next_sigma1_sq = sum((1-p)*((log(sample) - next_mu1)**2))/(N - sum(p))
  next_sigma2_sq = sum(p*(log(sample) - next_mu2)**2)/sum(p)
  likelihood_obs_next = likelihood(sample, next_mu1,next_mu2,sqrt(next_sigma1_sq),sqrt(next_sigma2_sq),next_tau)
  tau = next_tau
  mu1 = next_mu1
  mu2 = next_mu2
  sigma1_sq = next_sigma1_sq
  sigma2_sq = next_sigma2_sq
  iter = 1
  tol = 100
  while (abs(likelihood_obs_next - likelihood_obs) > tol) {
    piece1 = dlnorm(sample ,mean = mu2, sd = sqrt(sigma2_sq))*tau
    piece2 = dmixlnorm(sample, mu1, mu2, sqrt(sigma1_sq), sqrt(sigma2_sq), tau)
    p = piece1/piece2
    next_tau = sum(p)/N
    next_mu1 = (sum((1-p)*log(sample)))/(N - sum(p))
    next_mu2 = sum(p*log(sample))/sum(p)
    next_sigma1_sq = sum((1-p)*((log(sample) - next_mu1)**2))/(N - sum(p))
    next_sigma2_sq = sum(p*(log(sample) - next_mu2)**2)/sum(p)
    likelihood_obs = likelihood_obs_next
    likelihood_obs_next = likelihood(sample, next_mu1,next_mu2,sqrt(next_sigma1_sq),sqrt(next_sigma2_sq),next_tau)
    tau = next_tau
    mu1 = next_mu1
    mu2 = next_mu2
    sigma1_sq = next_sigma1_sq
    sigma2_sq = next_sigma2_sq
    iter = iter + 1
  }
  params = c(next_mu1,next_mu2,sqrt(next_sigma1_sq),sqrt(next_sigma2_sq),next_tau)
  return(params)
}
opt_function= function(snowdata3 = snowdata){
  #now, we have unconstrained optimisation. Thus, we transform the paramters so that they are on the real line.
  #no change from mu1 and mu2
  log_sigma_1 = log(sqrt(sigma1_sq))
  log_sigma_2 = log(sqrt(sigma2_sq))
  trans_tau = log(1/tau - 1)
  trans_params =  c(mu1,mu2,log_sigma_1,log_sigma_2,trans_tau)
  
  final = optim(par = trans_params, reallikelihood)
  params_final = final$par
  params_final[3:4] = exp(params_final[3:4])
  params_final[5] = 1/(1 + exp(params_final[5]))
  return(params_final)
}
params = em_function()
mu1 = params[1];mu2 = params[2];sigma1_sq   = params[3];sigma2_sq = params[4]
tau =params[5]
params_final = opt_function()
temp = seq(0,2,0.001)


func_plot= function(x){
  return(dmixlnorm(x, params_final[1],params_final[2],params_final[3], params_final[4], params_final[5]))
}
ggplot()+
  xlim(0,2)+
  geom_function(fun = func_plot)



ggplot()+
  geom_histogram(mapping = aes(x = jitter_function(), y = ..density..), breaks = c(snowdata$endpoint[1:47], 0))+
  xlim(0,2)+
  geom_function(fun = func_plot, colour = 'red', size = 1)







temp = seq(0,2,0.001)
#ggplot()+
#  geom_histogram(mapping = aes(x = jitter_function(), y = ..density..), breaks = c(snowdata$endpoint[1:47], 0))+
#  geom_point(mapping=aes(x = temp, y = dmixlnorm(temp, params_final[1],params_final[2],params_final[3], params_final[4], params_final[5])))
hist(jitter_function(), breaks = c(snowdata$endpoint[1:47], 0))
lines(temp,dmixlnorm(temp, params_final[1],params_final[2],params_final[3], params_final[4],  params_final[5]))













#ggplot()+
#  geom_function(dmixlnorm(temp, params_final[1],params_final[2],params_final[3], params_final[4], params_final[5]))
#hist(jitter_function(), breaks = c(snowdata$endpoint[1:47], 0))



boot_opt_function= function(snowdata3 = temp_snowdata){
  #now, we have unconstrained optimisation. Thus, we transform the paramters so that they are on the real line.
  #no change from mu1 and mu2
  log_sigma_1 = log(sqrt(temp_sigma1_sq))
  log_sigma_2 = log(sqrt(temp_sigma2_sq))
  trans_tau = log(1/temp_tau - 1)
  trans_params =  c(temp_mu1,temp_mu2,log_sigma_1,log_sigma_2,trans_tau)
  
  final = optim(par = trans_params, reallikelihood)
  params_final = final$par
  params_final[3:4] = exp(params_final[3:4])
  params_final[5] = 1/(1 + exp(params_final[5]))
  return(params_final)
}

bootstrap_n = 20000
#params_final is the truth in the botstrap world
#now, we do EM and optim on this
B = 5000
test_stat = rep(0, B)
for(i in 1:B){
  print(i)
  bootstrap_samples = rmixlnorm(bootstrap_n, params_final[1],params_final[2],params_final[3], params_final[4], 1 - params_final[5])
  
  a = hist(bootstrap_samples, breaks = c(snowdata$endpoint, 0))
  temp_snowdata = snowdata
  temp_snowdata$particles.detected = bootstrap_n
  temp_snowdata$retained....= 100*a$counts/bootstrap_n
  reallikelihood = function( params){
    mu1 = params[1]
    mu2 = params[2]
    sigma1 = exp(params[3])
    sigma2 = exp(params[4])
    tau = 1/(1 + exp(params[5]))
    temp = 0
    snowdata3 = temp_snowdata
    snowdata3$number = as.integer(snowdata3$retained....*snowdata3$particles.detected/100)
    for(i in 1:nrow(snowdata3)){
      temp = temp +snowdata3[i,6] * log(pmixlnorm(snowdata3[i,3],mu1, mu2, sigma1, sigma2, tau) - pmixlnorm(snowdata3[i,2], mu1, mu2, sigma1, sigma2, tau))
    }
    return(-temp)
  }
  temp = em_function(temp_snowdata)
  temp_mu1 = temp[1]
  temp_mu2 = temp[2]
  temp_sigma1_sq = temp[3]
  temp_sigma2_sq = temp[4]
  temp_tau = temp[5]
  temp = boot_opt_function()
  ksteststat = function(x){
    return(abs(pmixlnorm(x, params_final[1], params_final[2], params_final[3], params_final[4],  params_final[5]) - pmixlnorm(x, temp[1], temp[2], temp[3], temp[4],  temp[5])))
  }
  test_stat[i] =   optimize( ksteststat, lower = 0, upper = 4, maximum =  TRUE)$objective
}
ecdf = cumsum(snowdata$retained....)/100
e1cdf = pmixlnorm(snowdata$endpoint, params_final[1],params_final[2],params_final[3], params_final[4],  params_final[5])
pval = (sum( test_stat> max(abs(e1cdf - ecdf))) + 1)/(B+1)


save(params, params_final, pval,file="./Project-Snowflakes/final.RData")