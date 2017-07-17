source("R/compute_coverage.R")
source("R/wuenic.R")
source("R/utils.R")

download_who_all()

wuenic_date <- "20170715"
path <- file.path("scaled", wuenic_date)
dir.create(path, FALSE, TRUE)

d <- read_coverage("20170715", "20170712", 2016)
d_je <- scale_coverage("JE", d)
d_mena <- scale_coverage("MenA", d)

plot_estimates(d_je, file.path(path, "JE.pdf"))
plot_estimates(d_mena, file.path(path, "MenA.pdf"))
write.csv(d_je$scaled, file.path(path, "JE.csv"), row.names = FALSE)
write.csv(d_mena$scaled, file.path(path, "MenA.csv"), row.names = FALSE)

touchstone <- read_csv("meta/touchstone.csv")
import_wuenic(as.list(touchstone[1L, ]))
