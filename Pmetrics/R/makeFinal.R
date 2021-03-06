#' Extracts final cycle information from NPAG or IT2B run.
#'
#' This function will parse the output of \code{\link{NPparse}} or \code{\link{ITparse}} to generate a
#' list suitable for analysis and plotting of NPAG  or IT2B final cycle population values.
#'
#' @title Summarize NPAG or IT2B Final Cycle Population Values
#' @param data A suitable data object of the \emph{NPAG} or \emph{IT2B} class (see \code{\link{NPparse}} or \code{\link{ITparse}}).
#' @return The output of \code{makeFinal} is a list of class \emph{PMfinal}, which contains the following:
#' \item{popPoints }{(NPAG only) Dataframe of the final cycle joint population density of grid points
#'  with column names equal to the name of each random parameter plus \emph{prob} for the
#'  associated probability of that point}
#' \item{postPoints}{(NPAG only) Dataframe of posterior population points for each of the first 100 subject,
#' with columns id, point, parameters and probability.  The first column is the subject, the second column has the population
#' point number, followed by the values for the parameters in that point and the probability.}
#' \item{popMean }{The final cycle mean for each random parameter distribution}
#' \item{popSD }{The final cycle standard deviation for each random parameter distribution}
#' \item{popCV }{The final cycle coefficient of variation (SD/Mean) for each random parameter distribution}
#' \item{popVar }{The final cycle variance for each random parameter distribution}
#' \item{popCov }{The final cycle random parameter covariance matrix}
#' \item{popCor }{The final cycle random parameter correlation matrix}
#' \item{popMedian }{The final cycle median values for each random parameter}
#' \item{postMean }{The means of the posterior distributions for each parameter.}
#' \item{postSD }{The SDs of the posterior distributions for each parameter.}
#' \item{postVar }{The variances of the posterior distributions for each parameter.}
#' \item{shrinkage }{A data frame with the shrinkage for each parameter.  \code{popVar}
#' is comprised of variance(EBE) + variance(EBD), where EBE is the Emprical Bayes Estimate or mean of the posterior
#' distribution for the parameter. EBD is the Empirical Bayes Distribution, or
#' the full Bayesian posterior distribution. In other words, if Bayesian posterior distributions are wide
#' for a given parameter due to sparse or uninformative sampling, then most of the population variance is due
#' to this variance and shrinkage of the EBE variance is high because individual posterior estimates
#' shrink towards the population mean.}
#' \item{gridpts }{(NPAG only) Initial number of support points}
#' \item{nsub }{Number of subjects}
#' \item{ab }{Matrix of boundaries for random parameter values}
#' A plot method exists in \code{\link{plot}} for \emph{PMfinal} objects.
#' @author Michael Neely
#' @seealso \code{\link{NPparse}}, \code{\link{ITparse}},  \code{\link{plot.PMfinal}}
#' @examples
#' data(PMex1)
#' final <- makeFinal(NPdata.1)
#' final
#' names(final)

makeFinal <- function(data){
  if(length(grep("reshape2",installed.packages()[,1]))==0){
    install.packages("reshape2",repos="http://cran.cnr.Berkeley.edu",dependencies=T)
  }
  reshape2.installed <- require(reshape2,warn.conflicts=F,quietly=T)
  if(!reshape2.installed) stop("Error: connect to internet and re-run makePTA to download and install reshape2 package.\n")
  
  if(!inherits(data,"NPAG") & !inherits(data,"IT2B")) stop(paste("Use PMparse() to generate an Pmetrics NPAG or IT2B object.\n")) 
  if(inherits(data,"NPAG")){                                    
    #set the number of grid points at the beginning
    gridpts <- switch(data$indpts,2129,5003,10007,20011,40009,80021)
    if (is.null(gridpts)){
      gridpts <- (data$indpts-100)*80021
    }
    #summarize weighted corden
    wParVol <- prod(data$ab[,2]-data$ab[,1]) / gridpts
    if (nrow(data$corden)>1) {popMean <- colSums(data$corden[,1:data$nvar] * data$corden[,data$nvar+1] )  * wParVol} else {
      popMean <- data$corden[1:data$nvar] * data$corden[data$nvar+1]  * wParVol
    }
    
    if(nrow(data$corden)>1){
      popCov <- matrix(NA,ncol=data$nvar,nrow=data$nvar)
      for (i in 1:data$nvar){
        for (k in 1:data$nvar){
          popCov[i,k] <- sum(data$corden[,i] * data$corden[,k] * data$corden[,data$nvar+1]*wParVol) - popMean[i]*popMean[k]
        }  
      }
      if (any(popCov==0)) {popCor <- NA} else {popCor <- cov2cor(popCov)}
    } else {
      popCov <- matrix(rep(0,data$nvar**2),nrow=data$nvar)
      popCor <- matrix(rep(NA,data$nvar**2),nrow=data$nvar)
      diag(popCor) <- rep(1,data$nvar)
    }
    
    popPoints <- data.frame(data$corden)
    names(popPoints) <- c(data$par,"prob")
    popPoints$prob <- popPoints$prob*wParVol
    class(popPoints) <- c("popPoints","data.frame")
    
    names(popMean) <- data$par
    dimnames(popCov) <- list(data$par,data$par)
    if (all(!is.na(popCor))) dimnames(popCor) <- list(data$par,data$par)
    
    if(length(data$postden)>0){
      temp1 <- melt(data$postden)
      postPoints <- dcast(temp1,subj+nactvepost~density,value.var="value")
      postPoints <- postPoints[!is.na(postPoints$prob),]
      postPoints$prob <- postPoints$prob*wParVol
      names(postPoints)[1:2] <- c("id","point")
      postPoints$id <- data$sdata$id[postPoints$id]
    } else { postPoints <- NA}
    
    
    
    
    pointSum <- summary.PMfinal(popPoints)
    popMedian <- pointSum$value[pointSum$type=="WtMed" & pointSum$quantile==0.5]
    names(popMedian) <- data$par
    
    popVar <- diag(popCov)
    names(popVar) <- data$par
    
    popSD <- sqrt(popVar)
    names(popSD) <- data$par
    
    popCV <- abs(100*(popSD/popMean))
    names(popCV) <- data$par
    
    postMean <- data.frame(id=data$sdata$id,data$bmean)
    
    postSD <- data.frame(id=data$sdata$id,data$bsd)
    
    postVar <- data.frame(id=data$sdata$id,data$bsd^2)
    
    if(!all(is.na(postPoints))){
      nsub <- min(data$nsub,100)
      postCov <- array(NA,dim=c(data$nvar,data$nvar,nsub),
                       dimnames=list(par1=data$par,par2=data$par,subj=unique(data$sd$id)[1:nsub]))
      postCor <- array(NA,dim=c(data$nvar,data$nvar,nsub),
                       dimnames=list(par1=data$par,par2=data$par,subj=unique(data$sd$id)[1:nsub]))
      for(i in 1:nsub){
        temp2 <- postPoints[postPoints$id==data$sdata$id[i],]
        ret <- cov.wt(temp2[,3:(2+data$nvar)],wt=temp2$prob,cor=T,method="ML")
        postCov[,,i] <- ret$cov
        postCor[,,i] <- ret$cor
      }
    }
    
    
    #shrinkage
    varEBD <- apply(postVar[,-1],2,mean)
    sh <- varEBD/popVar
    sh.DF <- data.frame(par=data$par,shrinkage=sh)
    
    if(is.null(data$nranfix)) data$nranfix <- 0
    if(data$nranfix>0){
      popRanFix <- data$valranfix
      names(popRanFix) <- data$parranfix
    } else {popRanFix <- NULL}
    
    
    outlist <- list(popPoints=popPoints,popMean=popMean,popSD=popSD,popCV=popCV,popVar=popVar,
                    popCov=popCov,popCor=popCor,popMedian=popMedian,popRanFix=popRanFix,
                    postMean=postMean,postSD=postSD,postVar=postVar,postCov=postCov,postCor=postCor,
                    shrinkage=sh.DF,gridpts=gridpts,nsub=data$nsub,ab=data$ab,postPoints=postPoints)
    class(outlist)<-c("PMfinal","NPAG","list")
    return(outlist)
  }
  if(inherits(data,"IT2B")){                                    
    popMean <- data$imean[data$icyctot,]
    names(popMean) <- data$par
    
    popSD <- data$isd[data$icyctot,]
    names(popSD) <- data$par
    
    popVar <- popSD**2
    names(popVar) <- data$par
    
    popCV <- abs(data$icv[data$icyctot,])
    names(popCV) <- data$par
    
    popCov <- cov(data$lpar)
    dimnames(popCov) <- list(data$par,data$par)
    
    popCor <- cor(data$lpar)
    dimnames(popCor) <- list(data$par,data$par)
    
    popMedian <- data$imed[data$icyctot,]
    names(popMedian) <- data$par
    
    postMean <- data.frame(id=data$sdata$id,data$lpar)
    
    postSD <- data.frame(id=data$sdata$id,data$lsd)
    
    postVar <- data.frame(id=data$sdata$id,data$lsd^2)
    
    #shrinkage
    varEBD <- apply(postVar[,-1],2,mean)
    sh <- varEBD/popVar
    sh.DF <- data.frame(par=data$par,shrinkage=sh)
    
    
    outlist <- list(popMean=popMean,popSD=popSD,popCV=popCV,popVar=popVar,
                    popCov=popCov,popCor=popCor,popMedian=popMedian,postMean=postMean,postSD=postSD,postVar=postVar,shrinkage=sh.DF,nsub=data$nsub,ab=data$ab)
    class(outlist)<-c("PMfinal","IT2B","list")
    return(outlist)
  }
}

