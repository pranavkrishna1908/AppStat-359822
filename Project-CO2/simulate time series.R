library(tseries)
set.seed(123)
arma.process <- arima.sim(n = 4000, list(ma = c(0.8,0.4, 0.3, 0.4)))
#pacf(arma.process, main = "PACF plot for  process")
#acf(arma.process)
#plot(arma.process)
#plot(ts(rnorm(1000)))
arma.process2 = arima.sim(n = 4000, list(ar = c(-0.8, -0.001)))
acf(arma.process2)
process3 = cumsum(arma.process)
acf(process3)