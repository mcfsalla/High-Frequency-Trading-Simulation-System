% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/hftsimulator.r
\name{holdingsprofit}
\alias{holdingsprofit}
\title{holdingsprofit}
\usage{
holdingsprofit(instrumentid = character(), side = "long")
}
\arguments{
\item{instrumentid}{character, instrument identifier.}

\item{side}{character, "long" or "short", specifying holdings's side.}
}
\value{
numeric, holdings profit.
}
\description{
calculate unclosed holdings' dynamic profit. require
setting unclosed=TRUE in HFTsimulator.
total_profit = holdings_profit + closed_profit
}
\details{
long holdings' dynamic profit = holdings * (last_price - mean_open_price),
short holdings' dynamic profit = holdings * (mean_open_price - lastprice).
}
\examples{
\dontrun{
## get longholding's profit of TF1603
holdingsprofit("TF1603","long")
}
}
\seealso{
\link{HFTsimulator} \link{meanopen} \link{closedprofit}
}

