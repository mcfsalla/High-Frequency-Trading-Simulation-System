.extractinfo <- function(info=c("tradetime","lastprice","volume","orderbook","HMOS","presettleprice"),EXdata,ptradetime,plastprice,pvolume,pbuyhands,pbuyprice,psellhands,psellprice,ppresettleprice,timeformat="%Y-%m-%d %H:%M:%OS"){
    match.arg(info,choices = c("tradetime","lastprice","volume","orderbook","HMOS","presettleprice"))
    
    return(
        switch(info,
               tradetime=strftime(strptime(EXdata[ptradetime],timeformat),format = "%Y-%m-%d %H:%M:%OS"),
               lastprice=round(as.numeric(EXdata[plastprice]),5),
               volume=round(as.numeric(EXdata[pvolume]),5),
               orderbook=list(
                   buybook=data.frame(hands=round(as.numeric(EXdata[pbuyhands]),5),
                       price=round(as.numeric(EXdata[pbuyprice]),5)),
                   sellbook=data.frame(hands=round(as.numeric(EXdata[psellhands]),5),
                       price=round(as.numeric(EXdata[psellprice]),5))
                   ),
               HMOS=paste("1970-01-01",strftime(strptime(EXdata[ptradetime],timeformat),format = "%H:%M:%OS")),
               presettleprice=round(as.numeric(EXdata[ppresettleprice]),5)
               )
        )
}

.DEFMACRO <- function(..., expr){
    expr <- substitute(expr)
    a <- substitute(list(...))[-1]
    nn <- names(a)
    if (is.null(nn)) 
        nn <- rep("", length(a))
    for (i in 1:length(a)) {
        if (nn[i] == "") {
            nn[i] <- paste(a[[i]])
            msg <- paste(a[[i]], "not supplied")
            a[[i]] <- substitute(stop(foo), list(foo = msg))
        }
        if (nn[i] == "DOTS") {
            nn[i] <- "..."
            a[[i]] <- formals(function(...) {
            })[[1]]
        }
    }
    names(a) <- nn
    a <- as.list(a)
    ff <- eval(substitute(function() {
        tmp <- substitute(body)
        eval(tmp, parent.frame())
    }, list(body = expr)))
    formals(ff) <- a
    mm <- match.call()
    mm$expr <- NULL
    mm[[1]] <- as.name("macro")
    attr(ff, "source") <- c(deparse(mm), deparse(expr))
    ff
}

.updatecapital <- function(instrumentid,direction,hands,action,tradeprice,fee,closeprior="today",multiplier=10000){
    
    ## cost of current transaction
    cost <- 0
    idx <- .tradingstates$capital$instrumentid==instrumentid

    .capchange <- function(TODAY,TOTAL,HANDS,COMMISSION){
        ## cashchange <- (-1)*direction*HANDS*tradeprice-HANDS*tradeprice*COMMISSION
        ## idx <- .tradingstates$capital$instrumentid==instrumentid
        ## initialize new instrument
        if(!any(idx)){
            .tradingstates$capital <- rbind(.tradingstates$capital,data.frame(instrumentid=instrumentid,longholdingstoday=0,shortholdingstoday=0,longholdingspreday=0,shortholdingspreday=0,totallongholdings=0,totalshortholdings=0,cash=0,stringsAsFactors=FALSE))
            idx <- nrow(.tradingstates$capital)
        }
        handschange <- HANDS*direction
        trans <- handschange*tradeprice*(-1)*multiplier
        cost <- cost + HANDS*tradeprice*COMMISSION*multiplier
        .tradingstates$capital$cash[idx] <- .tradingstates$capital$cash[idx]+trans-cost
        .tradingstates$capital[[TODAY]][idx] <- .tradingstates$capital[[TODAY]][idx]+handschange
        .tradingstates$capital[[TOTAL]][idx] <- .tradingstates$capital[[TOTAL]][idx]+handschange
        ## capital calculation needs prices of many different instruments......
    }
    
    if(action=="close"){
        if(closeprior=="today"){
            if(direction==-1){
                ## close long, direction==-1!!!!!!!!!
                ## longholdings>=0
                if(hands<=.tradingstates$capital$longholdingstoday[idx]){
                    .capchange("longholdingstoday","totallongholdings",
                              hands,fee["closetoday"])
                }
                else{
                    close1 <- .tradingstates$capital$longholdingstoday[idx]
                    .capchange("longholdingstoday","totallongholdings",
                              close1,fee["closetoday"])
                    close2 <- hands-close1
                    .capchange("longholdingspreday","totallongholdings",
                              close2,fee["closepreday"])
                }
            }
            else{
                ## close short, direction==1!!!!!!!!!
                ## shortholdings<=0!!!!!!
                if(hands<=(-.tradingstates$capital$shortholdingstoday[idx])){
                    .capchange("shortholdingstoday","totalshortholdings",
                              hands,fee["closetoday"])
                }
                else{
                    close1 <- (-.tradingstates$capital$shortholdingstoday[idx])
                    .capchange("shortholdingstoday","totalshortholdings",
                              close1,fee["closetoday"])
                    close2 <- hands-close1
                    .capchange("shortholdingspreday","totalshortholdings",
                              close2,fee["closepreday"])
                }
            }
        }
        else{
            ## closeprior=="preday"
            if(direction==-1){
                ## close long, direction==-1!!!!!!!!!
                ## longholdings>=0
                if(hands<=.tradingstates$capital$longholdingspreday[idx]){
                    .capchange("longholdingspreday","totallongholdings",
                              hands,fee["closepreday"])
                }
                else{
                    close1 <- .tradingstates$capital$longholdingspreday[idx]
                    .capchange("longholdingspreday","totallongholdings",
                              close1,fee["closepreday"])
                    close2 <- hands-close1
                    .capchange("longholdingstoday","totallongholdings",
                              close2,fee["closetoday"])
                }
            }
            else{
                ## close short, direction==1!!!!!!!!!
                ## shortholdings<=0!!!!!!
                if(hands<=(-.tradingstates$capital$shortholdingspreday[idx])){
                    .capchange("shortholdingspreday","totalshortholdings",
                              hands,fee["closepreday"])
                }
                else{
                    close1 <- (-.tradingstates$capital$shortholdingspreday[idx])
                    .capchange("shortholdingspreday","totalshortholdings",
                              close1,fee["closepreday"])
                    close2 <- hands-close1
                    .capchange("shortholdingstoday","totalshortholdings",
                              close2,fee["closetoday"])
                }
            }
        }
    }
    else if(action=="open"){
        if(direction==1){
            .capchange("longholdingstoday","totallongholdings",
                      hands,fee["long"])
        }
        else{
            .capchange("shortholdingstoday","totalshortholdings",
                      hands,fee["short"])
        }
    }
    else if(action=="closetoday"){
        if(direction==-1){
            ## close long, direction==-1!!!!!!!!!
            .capchange("longholdingstoday","totallongholdings",
                      hands,fee["closetoday"])
        }
        else{
            ## close short, direction==1!!!!!!!!!
            .capchange("shortholdingstoday","totalshortholdings",
                      hands,fee["closetoday"])
        }
    }
    else{
        ## action=="closepreday"
        if(direction==-1){
            ## close long, direction==-1!!!!!!!!!
            .capchange("longholdingspreday","totallongholdings",
                      hands,fee["closepreday"])
        }
        else{
            ## close short, direction==1!!!!!!!!!
            .capchange("shortholdingspreday","totalshortholdings",
                      hands,fee["closepreday"])
        }
    }
    ## return transaction cost
    return(cost)
}

## record traded orders' history
.writetraded <- function(instrumentid,orderid,action,direction,tradehands,tradeprice){
    ## write memory then return
    if(.tradingstates$septraded){
        if(action=="open"){
            if(direction==1){
                .tradingstates$longopen <- rbind(
                    .tradingstates$longopen,
                    data.frame(
                        instrumentid=instrumentid,orderid=orderid,
                        tradehands=tradehands,
                        tradeprice=tradeprice,
                        stringsAsFactors = FALSE)
                )
            }
            else{
                ## direction==-1
                .tradingstates$shortopen <- rbind(
                    .tradingstates$shortopen,
                    data.frame(
                        instrumentid=instrumentid,orderid=orderid,
                        tradehands=tradehands,
                        tradeprice=tradeprice,
                        stringsAsFactors = FALSE)
                )
            }
        }
        else{
            ## action==close
            if(direction==1){
                .tradingstates$longclose <- rbind(
                    .tradingstates$longclose,
                    data.frame(
                        instrumentid=instrumentid,orderid=orderid,
                        tradehands=tradehands,
                        tradeprice=tradeprice,
                        stringsAsFactors = FALSE)
                )
            }
            else{
                ## direction==-1
                .tradingstates$shortclose <- rbind(
                    .tradingstates$shortclose,
                    data.frame(
                        instrumentid=instrumentid,orderid=orderid,
                        tradehands=tradehands,
                        tradeprice=tradeprice,
                        stringsAsFactors = FALSE)
                )
            }
        }
        return()
    }
    else{
        return()
    }
}

## involve mean open price calculation, must be executed before .trackunclosed()!!!!!!!!!!! 
.trackclosed <- function(instrumentid,action,direction,tradehands,tradeprice,multiplier){
    if(!.tradingstates$closed){
        return()
    }
    if(action=="close"){
        if(direction==1){
            ## short holding
            MEANOPEN <- meanopen(instrumentid,"short")
        }
        else{
            MEANOPEN <- meanopen(instrumentid,"long")
        }
        .tradingstates$closedtracker$cash[.tradingstates$closedtracker$instrumentid==instrumentid] <- .tradingstates$closedtracker$cash[.tradingstates$closedtracker$instrumentid==instrumentid]+(MEANOPEN-tradeprice)*tradehands*direction*multiplier
    }
    return()
}

## .trackunclosed open orders, use the same format as .writetraded
.trackunclosed <- function(instrumentid,orderid,action,direction,tradehands,tradeprice){
    if(!.tradingstates$unclosed){
        return()
    }
    
    if(action=="open"){
        if(direction==1){
            .tradingstates$unclosedlong <- rbind(
                .tradingstates$unclosedlong,
                data.frame(
                    instrumentid=instrumentid,orderid=orderid,
                    action="open",direction=1,
                    tradehands=tradehands,
                    tradeprice=tradeprice,
                    stringsAsFactors = FALSE)
            )
        }
        else{
            ## direction==-1
            .tradingstates$unclosedshort <- rbind(
                .tradingstates$unclosedshort,
                data.frame(
                    instrumentid=instrumentid,orderid=orderid,
                    action="open",direction=-1,
                    tradehands=tradehands,
                    tradeprice=tradeprice,
                    stringsAsFactors = FALSE)
            )
        }
    }
    else{
        ## action==close
        if(direction==1){
            OPEN <- .tradingstates$unclosedshort[.tradingstates$unclosedshort$instrumentid==instrumentid,]
            cumopen <- cumsum(OPEN$tradehands)
            remained <- cumopen-tradehands
            L <- nrow(OPEN)
            ## all have been closed
            if(all(remained<=0)){
                .tradingstates$unclosedshort <- rbind(.tradingstates$unclosedshort[.tradingstates$unclosedshort$instrumentid!=instrumentid,],OPEN[-(1:L),])
                return()
            }
            idx <- which(remained>0)[1]
            OPEN$tradehands[idx] <- remained[idx]
            .tradingstates$unclosedshort <- rbind(.tradingstates$unclosedshort[.tradingstates$unclosedshort$instrumentid!=instrumentid,],OPEN[idx:L,])
        }
        else{
            ## direction==-1
            OPEN <- .tradingstates$unclosedlong[.tradingstates$unclosedlong$instrumentid==instrumentid,]
            cumopen <- cumsum(OPEN$tradehands)
            remained <- cumopen-tradehands
            L <- nrow(OPEN)
            ## all have been closed
            if(all(remained<=0)){
                .tradingstates$unclosedlong <- rbind(.tradingstates$unclosedlong[.tradingstates$unclosedlong$instrumentid!=instrumentid,],OPEN[-(1:L),])
                return()
            }
            idx <- which(remained>0)[1]
            OPEN$tradehands[idx] <- remained[idx]
            .tradingstates$unclosedlong <- rbind(.tradingstates$unclosedlong[.tradingstates$unclosedlong$instrumentid!=instrumentid,],OPEN[idx:L,])
        }
    }
    return()
}

.writeorderhistory <- function(instrumentid,orderid,direction,hands,price,tradeprice,status,action,cost){
    ## write memory then return
    .tradingstates$orderhistory <- rbind(
        .tradingstates$orderhistory,
        data.frame(
            instrumentid=instrumentid,orderid=orderid,
            direction=direction,price=price,
            hands=hands,action=action,
            tradetime=.tradingstates$currenttradetime,
            tradeprice=tradeprice,
            cost=cost,status=status,
            initialhands=ifelse(action=="cancel",0,.tradingstates$orders$initialhands[.tradingstates$orders$orderid==orderid]),
            stringsAsFactors = FALSE)
    )
    return()
}

.writecapitalhistory <- function(instrumentid,tradeprice,tradehands,cost){

    .tradingstates$capitalhistory <- rbind(
        .tradingstates$capitalhistory,
        cbind(
            .tradingstates$capital[.tradingstates$capital$instrumentid==instrumentid,],
            data.frame(
                tradetime=.tradingstates$currenttradetime,
                tradeprice=tradeprice,tradehands=tradehands,cost=cost,
                stringsAsFactors=FALSE)
        )
    )
    return()
}


.eatbook <- function(instrumentid,market,book,fee,closeprior="today",multiplier){
    ## stop condition
    if(nrow(book)==0)
        return(market)
    if(book$hands[1]>=market$hands){    #eat market hands
        cost <- .updatecapital(instrumentid,market$direction,market$hands,market$action,book$price[1],fee,closeprior,multiplier)
        ## write history
        .writeorderhistory(instrumentid,market$orderid,market$direction,0,market$price,tradeprice=book$price[1],status=0,action=market$action,cost)
        .writecapitalhistory(instrumentid,tradeprice=book$price[1],tradehands=market$hands,cost)
        .writetraded(instrumentid,market$orderid,market$action,market$direction,market$hands,book$price[1])
        .trackclosed(instrumentid,market$action,market$direction,market$hands,book$price[1],multiplier)
        .trackunclosed(instrumentid,market$orderid,market$action,market$direction,market$hands,book$price[1])
        return(market[-1,])
    }
    else{                               #eat book
        ## match case
        cost <- .updatecapital(instrumentid,market$direction,book$hands[1],market$action,book$price[1],fee,closeprior,multiplier)
        market$hands <- market$hands-book$hands[1]
        ## write history
        .writeorderhistory(instrumentid,market$orderid,market$direction,market$hands,market$price,tradeprice=book$price[1],status=1,action=market$action,cost)
        .writecapitalhistory(instrumentid,tradeprice=book$price[1],tradehands=book$hands[1],cost)
        .writetraded(instrumentid,market$orderid,market$action,market$direction,book$hands[1],book$price[1])
        .trackclosed(instrumentid,market$action,market$direction,book$hands[1],book$price[1],multiplier)
        .trackunclosed(instrumentid,market$orderid,market$action,market$direction,book$hands[1],book$price[1])

        book <- book[-1,]
        ## recursion
        .eatbook(instrumentid,market,book,fee,closeprior,multiplier=multiplier)
    }
}

.eatpath <- function(instrumentid,limit,remained,fee,closeprior="today",multiplier){
    if(all(remained<=0))
        return(limit)
    idx <- which(remained>0)
    executed <- rep(0,length(remained))
    executed[idx] <- pmin(limit$hands[idx],remained[idx])
    limit$hands[idx] <- limit$hands[idx]-executed[idx]
    
    for(id in idx){
        cost <- .updatecapital(instrumentid = instrumentid,direction = limit$direction[id],hands = executed[id],action = limit$action[id],tradeprice = limit$price[id],fee=fee,closeprior = closeprior,multiplier=multiplier)
        .writeorderhistory(instrumentid,
                          orderid = limit$orderid[id],
                          direction = limit$direction[id],
                          hands = limit$hands[id],
                          price = limit$price[id],
                          tradeprice = limit$price[id],
                          status=ifelse(limit$hands[id]==0,0,1),
                          action=limit$action[id],cost=cost)
        .writecapitalhistory(instrumentid,tradeprice=limit$price[id],tradehands=executed[id],cost)
        .writetraded(instrumentid,limit$orderid[id],limit$action[id],limit$direction[id],executed[id],limit$price[id])
        .trackclosed(instrumentid,limit$action[id],limit$direction[id],executed[id],limit$price[id],multiplier)
        .trackunclosed(instrumentid,limit$orderid[id],limit$action[id],limit$direction[id],executed[id],limit$price[id])
    }
    
    ## limit$hands[idx] <- limit$hands[idx]-executed[idx]
    return(limit[limit$hands!=0,])
}

.eatprior <- function(book,volume){
    if(nrow(book)==0 | volume==0)
        return(list(
            book=data.frame(price=numeric(),hands=numeric(),stringsAsFactors = FALSE),
            volume=volume))
    else{
        if(book$hands[1]>volume){
            book$hands[1] <- book$hands[1]-volume
            return(list(book=book,volume=0))
        }
        else if(book$hands[1]==volume){
            return(list(book=book[-1,],volume=0))
        }
        else{ #book$hands[1]<volume
            return(.eatprior(book[-1,],volume-book$hands[1]))
        }
    }
}

.eatpriors <- function(limit,lastprice,volume,direction,preorderbook){
    if(direction==1){
        remained <- vapply(limit$orderid,function(id){
            idx <- limit$orderid==id
            ## price condition not met
            if(limit$price[idx]<lastprice){
                return(0)
            }else{
                ## eat high priority orders in preorderbook
                marketremained <- volume-sum(preorderbook$buybook$hands[preorderbook$buybook$price>limit$price[idx]])
                if(marketremained<=0){
                    return(0)
                }
                else{
                    ## eat prior limit orders
                    if(nrow(.tradingstates$limitprior[[id]])==0){
                        return(marketremained)
                    }else{
                        priorreamined <- marketremained-.tradingstates$limitprior[[id]]$hands
                        if(priorreamined>=0){
                            .tradingstates$limitprior[[id]] <- data.frame(hands=numeric(),price=numeric(),stringsAsFactors=FALSE)
                            return(priorreamined)
                        }else{
                            .tradingstates$limitprior[[id]]$hands <- -priorreamined
                            return(0)
                        }
                    }
                    
                }
            }
        },FUN.VALUE = 1)
    }
    else{
        ## direction==-1
        remained <- vapply(limit$orderid,function(id){
            idx <- limit$orderid==id
            ## price condition not met
            if(limit$price[idx]>lastprice){
                return(0)
            }else{
                ## eat high priority orders in preorderbook
                marketremained <- volume-sum(preorderbook$sellbook$hands[preorderbook$sellbook$price<limit$price[idx]])
                if(marketremained<=0){
                    return(0)
                }else{
                    ## eat prior limit orders
                    if(nrow(.tradingstates$limitprior[[id]])==0){
                        return(marketremained)
                    }else{
                        priorreamined <- marketremained-.tradingstates$limitprior[[id]]$hands
                        if(priorreamined>=0){
                            .tradingstates$limitprior[[id]] <- data.frame(hands=numeric(),price=numeric(),stringsAsFactors=FALSE)
                            return(priorreamined)
                        }else{
                            .tradingstates$limitprior[[id]]$hands <- -priorreamined
                            return(0)
                        }
                    }
                }
            }

        },FUN.VALUE = 1)
    }
    return(remained)
}

.cancledetector <- function(limit,book,direction){
    if(direction==1)
        dumped <- vapply(limit$orderid,function(id){
            ## no prior orders
            if(nrow(.tradingstates$limitprior[[id]])==0){
                return(1)
            }
            ## nothing change
            if(.tradingstates$limitprior[[id]]$price<min(book$price)){
                return(1)
            }
            else{
                change <- .tradingstates$limitprior[[id]]
                currenthands <- book$hands[match(change$price,book$price)]
                ## currenthands might be NA
                change$hands <- min(change$hands,ifelse(is.na(currenthands),0,currenthands))
                .tradingstates$limitprior[[id]] <- change[change$hands!=0,]
                return(1)
            }
        },FUN.VALUE = 1)
    else
        dumped <- vapply(limit$orderid,function(id){
            ## no prior orders
            if(nrow(.tradingstates$limitprior[[id]])==0){
                return(1)
            }
            if(.tradingstates$limitprior[[id]]$price>max(book$price)){
                ## nothing change
                return(1)
            }
            else{
                change <- .tradingstates$limitprior[[id]]
                currenthands <- book$hands[match(change$price,book$price)]
                ## currenthands might be NA
                change$hands <- min(change$hands,ifelse(is.na(currenthands),0,currenthands))
                .tradingstates$limitprior[[id]] <- change[change$hands!=0,]
                return(1)
            }
        },FUN.VALUE = 1)
    return()
}

.updateinstrument <- function(instrumentid,lastprice,volume,orderbook,preorderbook,fee,closeprior="today",multiplier){
    currentinstrument <- .tradingstates$orders[.tradingstates$orders$instrumentid==instrumentid,]
    
    if(nrow(currentinstrument)==0){
        return()
    }
    ## market order ----------------------
    ## at most two rows, long and short
    market <- currentinstrument[currentinstrument$price==0,]
    if(nrow(market)!=0){
        longopen <- market[market$direction==1&market$action=="open",]
        if(nrow(longopen)>0){
            longopen <- .eatbook(instrumentid,longopen,orderbook$sellbook,fee,closeprior,multiplier)
        }
        longclose <- market[market$direction==1&market$action=="close",]
        if(nrow(longclose)>0){
            longclose <- .eatbook(instrumentid,longclose,orderbook$sellbook,fee,closeprior,multiplier)
        }
        longclosetoday <- market[market$direction==1&market$action=="closetoday",]
        if(nrow(longclosetoday)>0){
            longclosetoday <- .eatbook(instrumentid,longclosetoday,orderbook$sellbook,fee,closeprior,multiplier)
        }
        longclosepreday <- market[market$direction==1&market$action=="closetoday",]
        if(nrow(longclosepreday)>0){
            longclosepreday <- .eatbook(instrumentid,longclosepreday,orderbook$sellbook,fee,closeprior,multiplier)
        }
        
        shortopen <- market[market$direction==-1&market$action=="open",]
        if(nrow(shortopen)>0){
            shortopen <- .eatbook(instrumentid,shortopen,orderbook$buybook,fee,closeprior,multiplier)
        }
        shortclose <- market[market$direction==-1&market$action=="close",]
        if(nrow(shortclose)>0){
            shortclose <- .eatbook(instrumentid,shortclose,orderbook$buybook,fee,closeprior,multiplier)
        }
        shortclosetoday <- market[market$direction==-1&market$action=="closetoday",]
        if(nrow(shortclosetoday)>0){
            shortclosetoday <- .eatbook(instrumentid,shortclosetoday,orderbook$buybook,fee,closeprior,multiplier)
        }
        shortclosepreday <- market[market$direction==-1&market$action=="closetoday",]
        if(nrow(shortclosepreday)>0){
            shortclosepreday <- .eatbook(instrumentid,shortclosepreday,orderbook$buybook,fee,closeprior,multiplier)
        }
        market <- rbind(longopen,longclose,longclosetoday,longclosepreday,shortopen,shortclose,shortclosetoday,shortclosepreday)
    }
    
    ## limit order ----------------------
    LIMIT <- currentinstrument[currentinstrument$price!=0,]
    if(nrow(LIMIT)!=0){
        ## sell initiated?
        mid <- (preorderbook$buybook$price[1]+preorderbook$sellbook$price[1])/2
        if(lastprice>mid+0.0000001){
            SI <- FALSE
        }
        else if(lastprice<mid-0.0000001){
            SI <- TRUE
        }
        else{
            SI <- ifelse(runif(1)>0.5,TRUE,FALSE)
        }
        
        longlimit <- LIMIT[LIMIT$direction==1,]
        if(nrow(longlimit)>0){
            ## IMPORTANT: affect mean open price
            longlimit <- longlimit[order(longlimit$price,decreasing = TRUE),]
            if( (volume==0) | (!SI))
                .cancledetector(longlimit,orderbook$buybook,direction=1)                #volume==0 | (!SI)
            if(SI & volume>0.0000001){
                ## eat prior limit orders first
                remained <- .eatpriors(limit=longlimit,lastprice=lastprice,volume = volume,direction=1,preorderbook=preorderbook)
                ## then eat our limit orders
                longlimit <- .eatpath(instrumentid = instrumentid,limit=longlimit,remained = remained,fee = fee,closeprior = closeprior,multiplier = multiplier)
            }
        }
        
        shortlimit <- LIMIT[LIMIT$direction==-1,]
        if(nrow(shortlimit)>0){
            shortlimit <- shortlimit[order(shortlimit$price,decreasing = FALSE),]
            if( (volume==0) | SI)
                .cancledetector(shortlimit,orderbook$sellbook,direction=-1)                #volume==0 | SI
            if((!SI) & volume>0.0000001){
                remained <- .eatpriors(limit=shortlimit,lastprice=lastprice,volume = volume,direction=-1,preorderbook=preorderbook)
                shortlimit <- .eatpath(instrumentid = instrumentid,limit=shortlimit,remained = remained,fee = fee,closeprior = closeprior,multiplier = multiplier)
            }
        }
        
        LIMIT <- rbind(longlimit,shortlimit)
    }
    
    ## combine remaining orders
    .tradingstates$orders <- rbind(market,LIMIT,.tradingstates$orders[.tradingstates$orders$instrumentid!=instrumentid,])
    
    return()
}

.priororders <- function(mostrecentorderbook,orderid,direction,price){
    if(direction==1){
        ## if all idx are FALSE, mostrecentorderbook$buybook[idx,] will be a data.frame with zero row
        .tradingstates$limitprior[[orderid]] <- mostrecentorderbook$buybook[mostrecentorderbook$buybook$price==price,]
    }
    else{
        ## if all idx are FALSE, mostrecentorderbook$sellbook[idx,] will be a data.frame with zero row
        .tradingstates$limitprior[[orderid]] <- mostrecentorderbook$sellbook[mostrecentorderbook$sellbook$price==price,]
    }
    return()
}



## detect timeout orders, must be executed before .orderchaser
.timeoutdetector <- function(){
    if(!any(.tradingstates$orders$timeoutlist)){
        return()
    }
    tradetime=.tradingstates$currenttradetime
    timeoutidx <- .tradingstates$orders$timeoutlist &
        as.numeric(difftime(tradetime,.tradingstates$orders$submitstart),unit="secs")>=.tradingstates$orders$timeoutsleep
    ## timeout, chase
    chaseidx <- timeoutidx & .tradingstates$orders$timeoutchase
    ## timeout, don't chase
    timeoutidx <- timeoutidx & (!.tradingstates$orders$timeoutchase)
    ## chase
    if(any(chaseidx)){
        .tradingstates$orders$chaselist[chaseidx] <- TRUE
    }
    ## cancel
    if(any(timeoutidx)){
        cancelall(orderid = .tradingstates$orders[timeoutidx])
    }
    return()
}

## support for multiple insstruments
.chasedetector <- function(orders){
    mostrecentorderbook <- list()
    ## get all related order books
    for(instrumentid in unique(orders$instrumentid)){
        mostrecentorderbook[[instrumentid]] <- .INSTRUMENT$orderbook[[instrumentid]]
    }
    ## return logical vector indicating wether to chase
    return(
    vapply(X=1:nrow(orders),FUN = function(i){
        return(
        (orders$direction[i]==1 & orders$price[i]!= mostrecentorderbook[[orders$instrumentid[i]]]$buybook$price[1]) |
            (orders$direction[i]==-1 & orders$price[i]!= mostrecentorderbook[[orders$instrumentid[i]]]$sellbook$price[1])
        )
    },FUN.VALUE = TRUE)
    )
}

## chase bid1 or ask1 price
.orderchaser <- function(){
    if(!any(.tradingstates$orders$chaselist)){
        return()
    }

    tradetime=.tradingstates$currenttradetime
    
    ## exceed idle time
    idx <- .tradingstates$orders$chaselist &
        as.numeric(difftime(tradetime,.tradingstates$orders$submitstart),unit="secs")>=.tradingstates$orders$chasesleep
    if(!any(idx)){
        return()
    }
    ## timeout orders
    orders <- .tradingstates$orders[idx,]
    chaseidx <- .chasedetector(orders)
    if(!any(chaseidx)){
        return()
    }
    orders <- orders[chaseidx,]
    cancelall(orderid = orders$orderid)
    ## automatically submit bid1 or ask1 price when price=NULL
    multisubmission(instrumentid = orders$instrumentid,direction = orders$direction,price=NULL,hands = orders$hands,action = orders$action,chaselist = TRUE,chasesleep=orders$chasesleep)
}

.cancelorders <- function(orders){
    if(nrow(orders)>0){
        for(i in seq_along(orders$orderid)){
            ordersubmission(instrumentid = orders$instrumentid[i],orderid = orders$orderid[i],action = "cancel")
        }
    }
    return()
}

.tradecenter <- function(instrumentid){
    if(!.tradingstates$tc){return()}

    tradetime=.tradingstates$currenttradetime
    
    if(.tradingstates$justchanged[instrumentid] | as.numeric(difftime(tradetime,.tradingstates$lastchange[instrumentid]),unit="secs")>=.tradingstates$Sleep){
        .tradingstates$justchanged[instrumentid] <- FALSE
        .tradingstates$lastchange[instrumentid] <- tradetime
        
        ## get orderbook
        orderbook <- .INSTRUMENT$orderbook[[instrumentid]]
        if(is.null(orderbook)){return()}
        longholding <- .tradingstates$th$longholding[.tradingstates$th$instrumentid==instrumentid]
        shortholding <- .tradingstates$th$shortholding[.tradingstates$th$instrumentid==instrumentid]
        
        currentinstrument <- .tradingstates$capital[.tradingstates$capital$instrumentid==instrumentid,]
        currentorder <- .tradingstates$orders[.tradingstates$orders$instrumentid==instrumentid,]


        ## long holdings
        longclose <- currentorder[(currentorder$action=="close"&currentorder$direction==-1),]
        longopen <- currentorder[(currentorder$action=="open"&currentorder$direction==1),]

        ## short holdings
        shortclose <- currentorder[(currentorder$action=="close"&currentorder$direction==1),]
        shortopen <- currentorder[(currentorder$action=="open"&currentorder$direction==-1),]
        
        ## operations on long holdings
        if(!is.null(longholding)){
            if(currentinstrument$totallongholdings<longholding){
                .cancelorders(longclose)
                .cancelorders(longopen[longopen$price!=orderbook$buybook$price[1],])
                if(sum(longopen$hands[longopen$price==orderbook$buybook$price[1]])>longholding-currentinstrument$totallongholdings){
                    .cancelorders(longopen[longopen$price==orderbook$buybook$price[1],])
                    ordersubmission(instrumentid,orderid = randomid(5),direction = 1,
                                    price = orderbook$buybook$price[1],
                                    hands = longholding-currentinstrument$totallongholdings,
                                    action = "open")
                }
                else if(sum(longopen$hands[longopen$price==orderbook$buybook$price[1]])<longholding-currentinstrument$totallongholdings){
                    ordersubmission(instrumentid,orderid = randomid(5),direction = 1,
                                    price = orderbook$buybook$price[1],
                                    hands = longholding-currentinstrument$totallongholdings-sum(longopen$hands[longopen$price==orderbook$buybook$price[1]]),
                                    action = "open")
                }
            }
            else if(currentinstrument$totallongholdings==longholding){
                .cancelorders(longclose)
                .cancelorders(longopen)
            }
            else{
                ## currentinstrument$totallongholdings>longholding
                .cancelorders(longopen)
                .cancelorders(longclose[longclose$price!=orderbook$sellbook$price[1],])
                if(sum(longclose$hands[longclose$price==orderbook$sellbook$price[1]])>currentinstrument$totallongholdings-longholding){
                    .cancelorders(longclose[longclose$price==orderbook$sellbook$price[1],])
                    ordersubmission(instrumentid,orderid = randomid(5),direction = -1,
                                    price = orderbook$sellbook$price[1],
                                    hands = currentinstrument$totallongholdings-longholding,
                                    action = "close")
                }
                else if(sum(longclose$hands[longclose$price==orderbook$sellbook$price[1]])<currentinstrument$totallongholdings-longholding){
                    ordersubmission(instrumentid,orderid = randomid(5),direction = -1,
                                    price = orderbook$sellbook$price[1],
                                    hands = currentinstrument$totallongholdings-longholding-sum(longclose$hands[longclose$price==orderbook$sellbook$price[1]]),
                                    action = "close")
                }
            }
        }
        
        ## operations on short holdings
        if(!is.null(shortholding)){
            if(currentinstrument$totalshortholdings>shortholding){
                .cancelorders(shortclose)
                .cancelorders(shortopen[shortopen$price!=orderbook$sellbook$price[1],])
                if(sum(shortopen$hands[shortopen$price==orderbook$sellbook$price[1]])>currentinstrument$totalshortholdings-shortholding){
                    .cancelorders(shortopen[shortopen$price==orderbook$sellbook$price[1],])
                    ordersubmission(instrumentid,orderid = randomid(5),direction = -1,
                                    price = orderbook$sellbook$price[1],
                                    hands = currentinstrument$totalshortholdings-shortholding,
                                    action = "open")
                }
                else if(sum(shortopen$hands[shortopen$price==orderbook$sellbook$price[1]])<currentinstrument$totalshortholdings-shortholding){
                    ordersubmission(instrumentid,orderid = randomid(5),direction = -1,
                                    price = orderbook$sellbook$price[1],
                                    hands = currentinstrument$totalshortholdings-shortholding-sum(shortopen$hands[shortopen$price==orderbook$sellbook$price[1]]),
                                    action = "open")
                }
            }
            else if(currentinstrument$totalshortholdings==shortholding){
                .cancelorders(shortclose)
                .cancelorders(shortopen)
            }
            else{
                ## currentinstrument$totalshortholdings<shortholding
                .cancelorders(shortopen)
                .cancelorders(shortclose[shortclose$price!=orderbook$buybook$price[1],])
                if(sum(shortclose$hands[shortclose$price==orderbook$buybook$price[1]])>shortholding-currentinstrument$totalshortholdings){
                    .cancelorders(shortclose[shortclose$price==orderbook$buybook$price[1],])
                    ordersubmission(instrumentid,orderid = randomid(5),direction = 1,
                                    price = orderbook$buybook$price[1],
                                    hands = shortholding-currentinstrument$totalshortholdings,
                                    action = "close")
                }
                else if(sum(shortclose$hands[shortclose$price==orderbook$buybook$price[1]])<shortholding-currentinstrument$totalshortholdings){
                    ordersubmission(instrumentid,orderid = randomid(5),direction = 1,
                                    price = orderbook$buybook$price[1],
                                    hands = shortholding-currentinstrument$totalshortholdings-sum(shortclose$hands[shortclose$price==orderbook$buybook$price[1]]),
                                    action = "close")
                }
            }
        }
        
    }
        
    return()
}

## record all prior limit orders' informations.
.verboselimitpriors <- function(){
    .tradingstates$verbosepriors[[.tradingstates$currenttradetime]] <- .tradingstates$limitprior
}

.initializeinstrument <- function(instrumentid,pbuyhands,pbuyprice,psellhands,psellprice,ptradetime,plastprice,pvolume,fee=c(long=0,short=0,closetoday=0,closepreday=0),closeprior="today",timeformat="%Y%m%d%H%M%OS",endoftheday="15:15:00.000",multiplier=10000){

    ## IMPORTANT NOTE:
    ## initialize only one instrument at a time!
    ## run .initializeinstrument multiple times for multiple instruments
    
    ## !!!!!!!!!
    CASH <- 0
    
    ## initialize instrument
    
    .INSTRUMENT$instrumentid[[instrumentid]] <- instrumentid
    
    .INSTRUMENT$pbuyhands[[instrumentid]] <- pbuyhands
    .INSTRUMENT$pbuyprice[[instrumentid]] <- pbuyprice
    ## sellbook:
    .INSTRUMENT$psellhands[[instrumentid]] <- psellhands
    .INSTRUMENT$psellprice[[instrumentid]] <- psellprice
    
    .INSTRUMENT$ptradetime[[instrumentid]] <- ptradetime
    .INSTRUMENT$plastprice[[instrumentid]] <- plastprice
    .INSTRUMENT$pvolume[[instrumentid]] <- pvolume
    ## .INSTRUMENT$ppresettleprice[[instrumentid]] <- ppresettleprice
    
    .INSTRUMENT$fee[[instrumentid]] <- fee
    .INSTRUMENT$closeprior[[instrumentid]] <- closeprior
    
    .INSTRUMENT$timeformat[[instrumentid]] <- timeformat
    
    .INSTRUMENT$endoftheday[[instrumentid]] <- paste("1970-01-01",endoftheday)
    .INSTRUMENT$tomidnight[[instrumentid]] <- difftime("1970-01-02 00:00:00.000",.INSTRUMENT$endoftheday[[instrumentid]],units = "secs")
    
    .INSTRUMENT$multiplier[[instrumentid]] <- multiplier
    
    .INSTRUMENT$pre[[instrumentid]] <- 0
    .INSTRUMENT$current[[instrumentid]] <- 0
    
    ## new day tracker
    .tradingstates$startoftheday[instrumentid] <- FALSE
    
    ## add zero holding tracker
    .tradingstates$closedtracker <- unique(rbind(
        .tradingstates$closedtracker,
        data.frame(instrumentid=instrumentid,cash=CASH,stringsAsFactors=FALSE)
    ))
    
    
    ## initialize trade center
    .tradingstates$justchanged[instrumentid] <- FALSE
    .tradingstates$lastchange[instrumentid] <- "1970-01-01 00:00:01.300"
    
    ## initialize instrument capital
    if(nrow(.tradingstates$capital[.tradingstates$capital$instrumentid==instrumentid,])==0){
        .tradingstates$capital <- rbind(
            .tradingstates$capital,
            data.frame(
                instrumentid=instrumentid,
                longholdingstoday=0, shortholdingstoday=0,
                longholdingspreday=0,shortholdingspreday=0,
                totallongholdings=0,totalshortholdings=0,
                cash=CASH,stringsAsFactors=FALSE
                )
            )
    }
    else{
        .tradingstates$capital$longholdingstoday[.tradingstates$capital$instrumentid==instrumentid] <- 0
        .tradingstates$capital$shortholdingstoday[.tradingstates$capital$instrumentid==instrumentid] <- 0
        .tradingstates$capital$longholdingspreday[.tradingstates$capital$instrumentid==instrumentid] <- 0
        .tradingstates$capital$shortholdingspreday[.tradingstates$capital$instrumentid==instrumentid] <- 0
        .tradingstates$capital$totallongholdings[.tradingstates$capital$instrumentid==instrumentid] <- 0
        .tradingstates$capital$totalshortholdings[.tradingstates$capital$instrumentid==instrumentid] <- 0
        .tradingstates$capital$cash[.tradingstates$capital$instrumentid==instrumentid] <- CASH
    }
    
    ## initialize target holding(after read holding) for trade center
    .tradingstates$th <- rbind(.tradingstates$th,
                               data.frame(instrumentid=instrumentid,
                                          longholding=.tradingstates$capital$totallongholdings[.tradingstates$capital$instrumentid==instrumentid],
                                          shortholding=.tradingstates$capital$totalshortholdings[.tradingstates$capital$instrumentid==instrumentid],
                                          stringsAsFactors = FALSE))
    .tradingstates$th <- unique(.tradingstates$th)
    if(nrow(.tradingstates$th)==0){
        stop("error while generating target holdings")
    }
    
    
}
