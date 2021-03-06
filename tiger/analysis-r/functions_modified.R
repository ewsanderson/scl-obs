###################################################################################################
## original code by Robert Dorazio
## modified by Mari Roberts, Jess Spencer, Charles Yackulic
## Integrated Species Distribution Models
## 1/8/2019
###################################################################################################

# print fitted models - modified by SCL
printList <- function(list) {
  for (item in 1:length(list)) {
    print(head(list[[item]]))
  }
}

# - modified by SCL 
tr <- function(x){
  (x-mean(x))/sd(x)
}

#likelihood functions
# Utility functions
logit = function(pp) { log(pp) - log(1-pp) }
expit = function(eta) {1/(1+exp(-eta))}

# function that calculates a probability of occupancy for each location in the dataset X
predict=function(mymodel, X){
  beta=mymodel$coefs[1:ncol(X),'Value']
  
  lambda=exp(X %*% beta)
  # psi =1- exp(-lambda*area)
  return(lambda)
}

#Function that fits IPP model
pb.ipp=function(X.po, W.po,X.back, W.back){
  
  beta.names=colnames(X.back)
  beta.names[1]='beta0'
  
  alpha.names=colnames(W.back)
  alpha.names[1]='alpha0'
  
  par.names=c(beta.names,	alpha.names)
  
  minrecipCondNum = 1e-6
  paramGuess = c(rep(.1, ncol(X.po)), rep(-.1, ncol(W.po)))
  
  # error with BFGS with current data (2/6/2020)
  fit.po = optim(par=paramGuess, fn=negLL.po, method='SANN', hessian=TRUE
                 , X.po=X.po, W.po=W.po,X.back=X.back,W.back=W.back ) # params for likelyhood function
  
  # calculating se with Hessian matrix
  # recipCondNum.po = NA
  # se.po = rep(NA, length(fit.po$par))
  # if (fit.po$convergence==0) {
  #   hess = ObsInfo.po(fit.po$par, X.po, W.po,X.back, W.back)
  #   ev = eigen(hess)$values
  #   recipCondNum.po = ev[length(ev)]/ev[1]
  #   if (recipCondNum.po>minrecipCondNum) {
  #     vcv = chol2inv(chol(hess))
  #     se.po = sqrt(diag(vcv))
  #  }
  #}
  
  #printing PO results
  #tmp= data.frame(par.names,fit.po$par,se.po)
  tmp= data.frame(par.names,fit.po$par)
  names(tmp)=c('Parameter name', 'Value')
  p=NULL
  p$coefs=tmp
  p$convergence=fit.po$convergence
  p$optim_message=fit.po$message
  p$value=fit.po$value
  # print("Estimated parameters beta and alpha", quote=FALSE)
  # print(p)
  return(p)
}

#Function that fits Mackenzie model - modified by SCL
so.model=function(X.so,y.so){
  
  beta.names=colnames(X.so)
  beta.names[1]='beta0'
  # find sites with at least one detection
  # y.so.pres = y.so[y.so[,2]>0,] #detection/non detection matrix for sites with detection in at least one of the surveys
  
  alpha.names.so=NULL
  
  par.names.so=c(beta.names,"alphaintercept")
  
  
  #Analyzing Presence-Absence data ------------------------------------------------
  
  minrecipCondNum = 1e-6
  
  paramGuess = c(rep(.2, dim(X.so)[2]), 0.1)
  fit.so = NA
  fit.so = optim(par=paramGuess, fn=negLL.so, method='BFGS', hessian=TRUE,y.so=y.so, X.so=X.so)
  
  # calculating se with Hessian matrix
  recipCondNum.so = NA
  se.so = rep(NA, length(fit.so$par))
  if (fit.so$convergence==0) {
    hess = fit.so$hessian
    ev = eigen(hess)$values
    recipCondNum.so = ev[length(ev)]/ev[1]
    if (recipCondNum.so>minrecipCondNum) {
      vcv = chol2inv(chol(hess))
      se.so = sqrt(diag(vcv))
    }
  }
  
  #print PA results
  tmp=data.frame(par.names.so,fit.so$par,se.so)
  names(tmp)=c('Parameter name', 'Value', 'Standard error')
  p=NULL
  p$coefs=tmp
  p$convergence=fit.so$convergence
  p$optim_message=fit.so$message
  p$value=fit.so$value
  return(p)
  
}


#Function that fits Combined data model
##### add 1 ands 2
##### use arrays

pbso.integrated=function(X.po, W.po, X.back, W.back, X.so1, X.so2, y.so1, y.so2){
  
  beta.names=colnames(X.back)
  beta.names[1]='beta0'
  
  alpha.names=colnames(W.back)
  alpha.names[1]='alpha0'
  
  alpha.names.so=NULL
  # for (i in 1:(dim(W.so)[3])){
  #   alpha.names.so[i]=paste("alpha",as.character(i-1), ".so", sep="")}
  
  alpha.names.so = c("alpha1","alpha2")
  
  par.names=c(beta.names,	alpha.names, alpha.names.so)
  
  # y.so.pres = y.so[rowSums(y.so)>=1,] #detection/non detection matrix for sites with detection in at least one of the surveys
  minrecipCondNum = 1e-6
  
  paramGuess = c(rep(0, dim(X.po)[2]),rep(0, dim(W.po)[2]), rep(0,2)) # change this later to make scaleable
  
  fit.pbso = optim(par=paramGuess, fn=negLL.pbso, method='SANN', hessian=TRUE
                   ,y.so1=y.so1, y.so2=y.so2, X.po=X.po, W.po=W.po, X.back=X.back, W.back=W.back, X.so1=X.so1, X.so2=X.so2) #### add in 1 and 2
  ### check debug here
  
  # calculating se with Hessian matrix
  recipCondNum.pbso = NA
  se.pbso = rep(NA, length(fit.pbso$par))
  if (fit.pbso$convergence==0) {
    hess = fit.pbso$hessian
    ev = eigen(hess)$values
    recipCondNum.pbso = ev[length(ev)]/ev[1]
    if (recipCondNum.pbso>minrecipCondNum) {
      vcv = chol2inv(chol(hess))
      se.pbso = sqrt(diag(vcv))
    }
  }
  
  #print Combined Data results
  tmp=data.frame(par.names,fit.pbso$par,se.pbso)
  names(tmp)=c('Parameter name', 'Value', 'Standard error')
  
  p=NULL
  p$coefs=tmp
  p$convergence=fit.pbso$convergence
  p$optim_message=fit.pbso$message
  p$value=fit.pbso$value
  return(p)
}

# negative loglikelihood function for Poisson point process
negLL.pp = function(param) {
  
  beta = param[1:dim(X.pp)[2]]
  lambda = exp(X.back %*% beta)
  mu = lambda * area.back
  
  logL.pp = sum(X.pp %*% beta) - sum(mu)
  
  (-1)*sum(logL.pp)
}

# negative loglikelihood function for thinned Poisson point process
negLL.po = function(param, X.po, W.po,X.back, W.back) {
  
  beta = param[1:dim(X.po)[2]]
  alpha = param[(dim(X.po)[2]+1):(dim(X.po)[2]+dim(W.po)[2])]
  # dim(X.back)
  # length(beta)
  # length(area.back)
  lambda = exp(X.back %*% beta)
  mu = lambda * area.back
  p = expit(W.back %*% alpha)
  
  logL.po = sum(X.po %*% beta) + sum(W.po %*% alpha) - sum(log(1 + exp(W.po %*% alpha))) - sum(mu*p)
  
  (-1)*sum(logL.po)
}

# Observed hessian matrix of negative loglikelihood function for thinned Poisson point process
ObsInfo.po = function(param, X.po,W.po,X.back, W.back) {
  
  beta = param[1:dim(X.back)[2]]
  alpha = param[(dim(X.back)[2]+1):(dim(X.back)[2]+dim(W.back)[2])]
  
  lambda = exp(X.back %*% beta)
  mu = lambda * area.back
  p = expit(W.back %*% alpha)
  
  p.po = expit(W.po %*% alpha)
  
  nxcovs = length(beta)
  nwcovs = length(alpha)
  
  nparams = nxcovs + nwcovs
  Hmat = matrix(nrow=nparams, ncol=nparams)
  
  #  beta partials
  for (i in 1:nxcovs) {
    for (j in 1:i) {
      Hmat[i,j] = sum(X.back[,i] * X.back[,j] * mu * p)
      Hmat[j,i] = Hmat[i,j]
    }
  }
  
  # alpha partials
  for (i in 1:nwcovs) {
    for (j in 1:i) {
      Hmat[nxcovs+i, nxcovs+j] = sum(W.back[,i] * W.back[,j] * mu * p * ((1-p)^3) * (1 - exp(2 * W.back %*% alpha)) ) + sum(W.po[,i] * W.po[,j] * p.po * (1-p.po))
      Hmat[nxcovs+j, nxcovs+i] = Hmat[nxcovs+i, nxcovs+j]
    }
  }
  
  # alpha-beta partials
  for (i in 1:nwcovs) {
    for (j in 1:nxcovs) {
      Hmat[nxcovs+i, j] = sum(X.back[,j] * W.back[,i] * mu * p * (1-p))
      Hmat[j, nxcovs+i] = Hmat[nxcovs+i, j]
    }
  }
  
  Hmat
}

# Expected hessian matrix of negative loglikelihood function for thinned Poisson point process
FisherInfo.po = function(param) {
  
  beta = param[1:dim(X.back)[2]]
  alpha = param[(dim(X.back)[2]+1):(dim(X.back)[2]+dim(W.back)[2])]
  
  lambda = exp(X.back %*% beta)
  mu = lambda * area.back
  p = expit(W.back %*% alpha)
  
  
  nxcovs = length(beta)
  nwcovs = length(alpha)
  
  nparams = nxcovs + nwcovs
  Hmat = matrix(nrow=nparams, ncol=nparams)
  
  #  beta partials
  for (i in 1:nxcovs) {
    for (j in 1:i) {
      Hmat[i,j] = sum(X.back[,i] * X.back[,j] * mu * p)
      Hmat[j,i] = Hmat[i,j]
    }
  }
  
  # alpha partials
  for (i in 1:nwcovs) {
    for (j in 1:i) {
      Hmat[nxcovs+i, nxcovs+j] = sum(W.back[,i] * W.back[,j] * mu * p * ((1-p)^3) * (1 - exp(2 * W.back %*% alpha)) ) + sum(W.back[,i] * W.back[,j] * p * (1-p) * mu * p)
      Hmat[nxcovs+j, nxcovs+i] = Hmat[nxcovs+i, nxcovs+j]
    }
  }
  
  # alpha-beta partials
  for (i in 1:nwcovs) {
    for (j in 1:nxcovs) {
      Hmat[nxcovs+i, j] = sum(X.back[,j] * W.back[,i] * mu * p * (1-p))
      Hmat[j, nxcovs+i] = Hmat[nxcovs+i, j]
    }
  }
  
  Hmat
}

# negative loglikelihood function for Mackenzie model - modified by SCL
negLL.so = function(param, y.so,X.so) {
  
  beta = param[1:dim(X.so)[2]]
  alpha = param[(dim(X.so)[2]+1)] # one parameter
  
  #temp --------------------------
  area.so=1
  
  lambda.so = exp(as.matrix(X.so) %*% beta)
  psi =1- exp(-lambda.so*area.so) # vector expected occupancy
  
  # fourth parameter for additonal survey
  # ------------
  
  mean(lambda.so)
  mean(psi)
  
  # p.so = matrix(nrow=dim(W.so)[1], ncol=J.so)
  # 
  # for (j in 1:J.so) {
  # 	p.so[, j] = expit(as.matrix(W.so[,j,], nrow=dim(W.so)[1]) %*% alpha)
  # }
  p.so = expit(alpha) # prob of detection
  
  # prob of detection for sites with presence at least in one of the surveys, and with no presence detected
  # p.so.pres=p.so[y.so[,2]>=1,]
  # p.so.non.pres=p.so[y.so[,2]==0,]
  
  # prob of occupancy for sites with presence at least in one of the surveys, and with no presence detected
  # psi.pres=psi[rowSums(y.so)>=1,]
  # psi.non.pres=psi[rowSums(y.so)==0,]
  
  
  #If there is only one site with no observed animals R automatically turns p.so.non.pres in a vector while we need it in a form of a matrix with 1 row and J.so (number of surveys rows) for the function rowProds to work
  # if (length(p.so.non.pres)==J.so) {dim(p.so.non.pres)=c(1,J.so)}
  # 
  # so.pres=sum(log(psi.pres)+rowSums(y.so.pres*log(p.so.pres)+(1-y.so.pres)*log(1-p.so.pres)))
  # 
  # 
  # so.non.pres=0
  # if (!is.null(psi.non.pres))	{
  # 	so.non.pres=sum(log(psi.non.pres*rowProds(1-p.so.non.pres)+1-psi.non.pres))
  # }
  # 
  # -(so.pres+so.non.pres)
  
  lik <- ifelse(y.so[,2]==0,(1-psi)+psi*(1-p.so)^y.so[,1],psi*(p.so^y.so[,2])*((1-p.so)^(y.so[,1]-y.so[,2])))
  -1*sum(log(lik))
}

negLL.pbso = function(param, y.so1, y.so2, X.po, W.po, X.back, W.back, X.so1, X.so2)  {
  
  param.po = param[1:(dim(X.po)[2]+dim(W.po)[2])]
  param.so1 = param[c(1:dim(X.po)[2], (dim(X.po)[2]+dim(W.po)[2]+1))]
  param.so2 = param[c(1:dim(X.po)[2], (dim(X.po)[2]+dim(W.po)[2]+2))]
  
  negLL.po(param.po, X.po, W.po,X.back, W.back ) + negLL.so(param.so1,y.so1,X.so1) +  negLL.so(param.so2,y.so2,X.so2)

}
