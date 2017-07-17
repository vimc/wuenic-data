scale_coverage <- function(vaccine, d) {
  info <- read_csv("meta/who_vaccines.csv")
  vaccine_who <- info$code[match(vaccine, info$code_montagu)]
  countries <-
    read_csv(file.path(sprintf("meta/countries_%s.csv", vaccine)))[[1]]

  to_scale <- d$reported[d$reported$ISO_code %in% countries &
                         d$reported$Vaccine == vaccine_who, ]
  to_scale <- to_scale[order(to_scale$ISO_code), ]
  countries <- to_scale$ISO_code

  prepare <- function(x) {
    x <- x[x$ISO_code %in% countries & x$Vaccine %in% d$wuenic$Vaccine, ]
    x$code <- paste(x$ISO_code, x$Vaccine, sep = "\r")
    x[order(x$code), ]
  }
  dsub <- lapply(d, prepare)
  keep <- intersect(dsub$reported$code, dsub$wuenic$code)
  dsub <- lapply(dsub, function(x) x[x$code %in% keep, ])

  years <- grep("^[0-9]{4}$", names(dsub$reported), value = TRUE)

  ratio <- cbind(dsub$reported[setdiff(names(dsub$reported), years)],
                 dsub$wuenic[years] / dsub$reported[years])
  adjustment <- aggregate(ratio[years], ratio["ISO_code"], mean, na.rm = TRUE)

  scaled <- to_scale
  scaled[years] <- to_scale[years] * adjustment[years]

  list(adjustment = adjustment,
       scaled = scaled,
       to_scale = to_scale,
       reported = dsub$reported,
       wuenic = dsub$wuenic,
       years = years)
}

read_coverage <- function(date_wuenic, date_reported, year_max,
                          year_min = 1980) {
  filename_w <- download_who("wuenic", date_wuenic)
  filename_r <- download_who("reported", date_reported)
  vaccines_w <- readxl::excel_sheets(filename_w)
  vaccines_r <- readxl::excel_sheets(filename_r)

  info <- read_csv("meta/who_vaccines.csv")
  shared <- intersect(tolower(vaccines_w), tolower(vaccines_r))
  shared_w <- vaccines_w[match(shared, tolower(vaccines_w))]
  shared_r <- vaccines_r[match(shared, tolower(vaccines_r))]
  shared <- info$code[match(shared, tolower(info$code))]

  sheets_r <- c(shared_r, c("JapEnc", "MenA"))

  years <- as.character(year_min:year_max)

  read_sheet <- function(sheet, filename) {
    d <- as.data.frame(read_xls(filename, sheet))
    msg <- setdiff(years, names(d))
    if (length(msg) > 0L) {
      d[msg] <- NA_real_
    }
    lgl <- vapply(d[years], is.logical, logical(1))
    d[years][lgl] <- lapply(d[years][lgl], as.numeric)
    ok <- vapply(d[years], is.numeric, logical(1))
    if (any(!ok)) {
      d[years][!ok] <- lapply(d[years][!ok], fix_numeric)
    }
    i <- match(tolower(sheet), tolower(shared))
    d$Vaccine <- if (is.na(i)) sheet else shared[i]
    cbind(d[setdiff(names(d), years)], d[years])
  }
  dat_w <- do.call("rbind", lapply(shared_w, read_sheet, filename_w))
  dat_r <- do.call("rbind", lapply(sheets_r, read_sheet, filename_r))

  list(wuenic = dat_w, reported = dat_r)
}

fix_numeric <- function(x) {
  ret <- suppressWarnings(as.numeric(x))
  changed <- is.na(ret) & !is.na(x)
  if (length(changed) > 0L) {
    message(sprintf("Changed %d values to NA: %s",
                    sum(changed), paste(x[changed], collapse = ", ")))
  }
  ret
}

plot_estimates <- function(x, filename) {
  pdf(filename)
  on.exit(dev.off())
  for (country in unique(x$reported$ISO_code)) {
    plot1(country, x)
  }
}

plot1 <- function(country, x) {
  op <- par(mfrow = c(2, 2),
            mgp = c(2, 1, 0),
            mar = c(3, 3, 1, 1) + 0.1,
            oma = c(0, 0, 2, 0))
  on.exit(par(op))

  pch <- c(reported = 1, wuenic = 4)
  i <- x$reported$ISO_code == country

  m_reported <- t(as.matrix(x$reported[i, x$years]))
  m_wuenic <- t(as.matrix(x$wuenic[i, x$years]))

  matplot(x$years, m_reported, pch = pch[["reported"]],
          ylim = c(0, 100), xlab = "year", ylab = "coverage [%]")
  matpoints(x$years, m_wuenic, pch = pch[["wuenic"]])
  legend("topleft", pch = pch, col = 1, legend = names(pch),  bty = "n")

  i <- x$reported$ISO_code == country
  matplot(m_wuenic, m_reported, pch = 1,
          xlab = "estimated coverage [%]", ylab = "reported coverage [%]")
  abline(0, 1, lty = 2, col = "grey")

  matplot(x$years, m_wuenic / m_reported, pch = 1,
          ylim = c(0, 2), xlab = "year", ylab = "coverage [%]")
  points(x$years, x$adjustment[x$adjustment$ISO_code == country, x$years],
         pch = 19)

  plot(NULL, xlim = c(0,1), ylim = c(0,1), axes = FALSE, xlab = "", ylab = "")
  legend("topleft", pch = 1, col = seq_len(sum(i)),
         legend = x$reported$Vaccine[i],  bty = "n")

  mtext(x$reported$Cname[i][[1]], outer = TRUE)
}
