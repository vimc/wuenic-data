source("R/wuenic.R")
source("R/utils.R")
touchstone <- read_csv("meta/touchstone.csv")
import_wuenic(as.list(touchstone[1L, ]))
