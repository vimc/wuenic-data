read_csv <- function(...) {
  read.csv(..., stringsAsFactors = FALSE, check.names = FALSE)
}

data_frame <- function(...) {
  data.frame(..., stringsAsFactors = FALSE)
}

montagu_connection <- function(host = "localhost", port = 5432) {
  DBI::dbConnect(RPostgres::Postgres(),
                 dbname = "montagu",
                 host = host,
                 port = port,
                 password = "changeme",
                 user = "vimc")
}

read_xls <- function(...) {
  oo <- options(warnPartialMatchArgs = FALSE)
  if (!is.null(oo$warnPartialMatchArgs)) {
    on.exit(options(oo))
  }
  readxl::read_xls(...)
}

insert_values_into <- function(con, table, d, key = NULL,
                               text_key = FALSE, id = NULL) {
  id <- id %||% (if (length(key) == 1L) key else "id")
  stopifnot(length(id) == 1L)
  insert1 <- function(i) {
    x <- as.list(d[i, , drop = FALSE])
    x <- x[!vlapply(x, is.na)]
    sql <- c(sprintf("INSERT INTO %s", table),
             sprintf("  (%s)", paste(names(x), collapse = ", ")),
             "VALUES",
             sprintf("  (%s)", paste0("$", seq_along(x), collapse = ", ")),
             sprintf("RETURNING %s", id))
    sql <- paste(sql, collapse = "\n")
    if (is.null(key)) {
      DBI::dbGetQuery(con, sql, x)[[id]]
    } else {
      ## Try and retrieve first:
      sql_get <- c(sprintf("SELECT %s FROM %s WHERE", id, table),
                   paste(sprintf("%s = $%d", key, seq_along(key)),
                         collapse = " AND "))
      ret <- DBI::dbGetQuery(con, paste(sql_get, collapse = "\n"), x[key])[[id]]
      if (length(ret) == 0L) {
        ret <- DBI::dbGetQuery(con, sql, x)[[id]]
      }
      ret
    }
  }

  if (!is.data.frame(d)) {
    d <- as.data.frame(d, stringsAsFactors = FALSE)
  }
  tmp <- lapply(seq_len(nrow(d)), insert1)
  vapply(tmp, identity, if (text_key) character(1) else integer(1))
}

`%||%` <- function(a, b) {
  if (is.null(a)) b else a
}

vlapply <- function(X, FUN, ...) {
  vapply(X, FUN, logical(1), ...)
}
