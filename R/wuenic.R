download_wuenic <- function(date) {
  versions <- read_csv("meta/versions.csv")
  if (!date %in% versions$date) {
    stop("Unknown date ", date)
  }

  dir.create("xls", FALSE, TRUE)
  dest <- file.path("xls", paste0(date, ".xls"))

  if (!file.exists(dest)) {
    url <-
      "http://www.who.int/entity/immunization/monitoring_surveillance/data/coverage_estimates_series.xls"
    tmp <- tempfile()
    download.file(url, tmp)
    hash <- unname(tools::md5sum(tmp))
    if (hash != versions$hash[versions$date == date]) {
      stop("Unexpected hash!")
    }
    file.copy(tmp, dest)
    file.remove(tmp)
  }
  dest
}

prepare_wuenic <- function(date) {
  extract <- read_csv("meta/extract.csv")
  extract <- extract[extract$date == date, , drop = FALSE]
  xls <- download_wuenic(date)

  prepare1 <- function(i) {
    x <- as.list(extract[i, ])
    d <- read_xls(xls, sheet = x$sheet_name)
    if (d$Vaccine[[1]] != x$sheet_name) {
      ## Avoid an old readxl bug
      stop("Read the wrong sheet?")
    }

    years <- grep("^[0-9]{4}$", names(d), value = TRUE)

    fix <- vapply(d[years], is.logical, logical(1))
    d[years][fix] <- lapply(d[years][fix], as.numeric)
    ok <- vapply(d[years], is.numeric, logical(1))

    if (any(!ok)) {
      stop("FIX TYPE")
    }

    data_frame(index = unname(i),
               country = rep(d$ISO_code, length(years)),
               year = rep(years, each = nrow(d)),
               coverage = unlist(d[years], use.names = FALSE),
               row.names = NULL)
  }

  res <- lapply(seq_len(nrow(extract)), prepare1)

  data <- do.call(rbind, res)
  info <- data_frame(index = seq_len(nrow(extract)),
                     extract[c("date", "vaccine", "disease",
                               "gavi_support_level", "activity_type")])

  list(data = data, info = info)
}

import_wuenic <- function(x) {
  x$touchstone <- sprintf("%s-%d", x$touchstone_name, x$touchstone_version)
  dat <- prepare_wuenic(x$date)

  host <- Sys.getenv("MONTAGU_DB_HOST", "localhost")
  port <- as.integer(Sys.getenv("MONTAGU_DB_PORT", 8888))
  con <- montagu_connection(host, port)

  res <- DBI::dbGetQuery(con, "SELECT id FROM touchstone WHERE id = $1",
                         x$touchstone)$id
  if (length(res) > 0L) {
    message(sprintf("Already imported data as %s", x$touchstone))
    return()
  }

  d_touchstone_name <- data_frame(id = x$touchstone_name,
                                  description = x$touchstone_name_description)
  insert_values_into(con, "touchstone_name", d_touchstone_name,
                     key = "id", text_key = TRUE)

  year_start <- min(dat$data$year[!is.na(dat$data$coverage)])
  year_end <- max(dat$data$year[!is.na(dat$data$coverage)])
  d_touchstone <- data_frame(id = x$touchstone,
                             touchstone_name = x$touchstone_name,
                             version = x$touchstone_version,
                             description = x$touchstone_description,
                             status = "in-preparation",
                             year_start = year_start,
                             year_end = year_end)
  insert_values_into(con, "touchstone", d_touchstone, text_key = TRUE)

  coverage_set <- data_frame(name = sprintf("wuenic-%s", dat$info$vaccine),
                             touchstone = x$touchstone,
                             vaccine = dat$info$vaccine,
                             gavi_support_level = dat$info$gavi_support_level,
                             activity_type = dat$info$activity_type)
  id <- insert_values_into(con, "coverage_set", coverage_set)

  coverage <- dat$data[c("country", "year", "coverage")]
  coverage$coverage_set <- id[match(dat$data$index, dat$info$index)]
  coverage$age_from <- 0L
  coverage$age_to <- 0L
  coverage$target <- NA_real_

  DBI::dbWriteTable(con, "coverage", coverage, append = TRUE)
}
