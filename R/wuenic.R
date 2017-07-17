download_who_all <- function() {
  versions <- read_csv("meta/versions.csv")
  get <- tapply(versions$date, versions$type, max)
  for (i in seq_along(get)) {
    download_who(names(get)[[i]], get[[i]])
  }
}

download_who <- function(type, date) {
  versions <- read_csv("meta/versions.csv")
  idx <- date == versions$date & type == versions$type
  x <- versions[idx, ]
  if (nrow(x) == 0) {
    stop(sprintf("Unknown who dataset %s/%s", type, date))
  }

  dir.create("xls", FALSE, TRUE)
  dest <- file.path("xls", sprintf("%s_%s.xls", type, date))

  if (!file.exists(dest)) {
    message(sprintf("Downloading %s/%s", type, date))
    url <- who_url(type)
    tmp <- tempfile()
    download.file(url, tmp)
    if (is.na(x$hash)) {
      versions$hash[idx] <- unname(tools::md5sum(tmp))
      write.csv(versions, "meta/versions.csv", row.names = FALSE)
    } else {
      hash <- unname(tools::md5sum(tmp))
      if (hash != x$hash) {
        stop("Unexpected hash!")
      }
    }
    file.copy(tmp, dest)
    file.remove(tmp)
  }
  dest
}

who_url <- function(type) {
  switch(
    type,
    wuenic = "http://www.who.int/entity/immunization/monitoring_surveillance/data/coverage_estimates_series.xls",
    reported = "http://www.who.int/entity/immunization/monitoring_surveillance/data/coverage_series.xls",
    hpv_doses = "http://www.who.int/immunization/monitoring_surveillance/data/HPVadmin.xls",
    schedule = "http://www.who.int/entity/immunization/monitoring_surveillance/data/schedule_data.xls",
    stop("Unknown who data type ", type))
}

prepare_wuenic <- function(date) {
  extract <- read_csv("meta/extract.csv")
  extract <- extract[extract$date == date, , drop = FALSE]
  xls <- download_who("coverage", date)

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

  d_touchstone <- data_frame(id = x$touchstone,
                             touchstone_name = x$touchstone_name,
                             version = x$touchstone_version,
                             description = x$touchstone_description,
                             status = "in-preparation")
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
