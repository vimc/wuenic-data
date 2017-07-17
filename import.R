source("R/wuenic.R")
source("R/utils.R")

download_who_all()

download_who("wuenic", "20161020")
download_who("wuenic", "20170715")

touchstone <- read_csv("meta/touchstone.csv")
import_wuenic(as.list(touchstone[1L, ]))
