# 01_sources.R -- loaders. Each returns a tibble(date, value) or a raw table, caches the
# downloaded bytes under data/raw/<source>/, and never applies a unit conversion.

# Tested 2026-11-08: fred.stlouisfed.org drops requests carrying a custom User-Agent string
# ("HTTP/2 stream was not closed cleanly" / timeouts), so no user_agent() is set, and HTTP/1.1
# is forced (CURL_HTTP_VERSION_1_1 == 2) to avoid HTTP/2 connection-reuse errors.
HTTP11 <- httr::config(http_version = 2)

.get_with_retry <- function(url, tries = 3, pause = 2) {
  for (i in seq_len(tries)) {
    resp <- tryCatch(httr::GET(url, HTTP11, httr::timeout(60)), error = function(e) NULL)
    if (!is.null(resp) && httr::status_code(resp) == 200) return(resp)
    Sys.sleep(pause * i)
  }
  stop("download failed after ", tries, " tries: ", url)
}

.cache_write <- function(bytes, source, name) {
  dir <- ensure_dir(pipe_path("data", "raw", source))
  f <- file.path(dir, paste0(name, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
  writeBin(bytes, f)
  invisible(f)
}

# ---- FRED (keyless CSV) ---------------------------------------------------------
fred_csv <- function(id) {
  url <- paste0("https://fred.stlouisfed.org/graph/fredgraph.csv?id=", id)
  resp <- .get_with_retry(url)
  txt <- httr::content(resp, as = "text", encoding = "UTF-8")
  if (!startsWith(txt, "observation_date")) stop("FRED did not return a CSV for ", id)
  .cache_write(charToRaw(txt), "fred", id)
  df <- read_csv(I(txt), show_col_types = FALSE, na = c(".", ""),
                 col_types = cols(observation_date = col_date(), .default = col_double()))
  names(df) <- c("date", "value")
  df
}

# Units string from the FRED series page (for the unit-drift test).
fred_units <- function(id) {
  resp <- .get_with_retry(paste0("https://fred.stlouisfed.org/series/", id))
  html <- httr::content(resp, as = "text", encoding = "UTF-8")
  # The units string is the text right after the latest-observation value, e.g.
  #   <span class="series-meta-observation-value">277,656</span> |  Millions of U.S. Dollars, Not Seasonally Adjusted |
  # Anchoring there avoids matching a word in the title (the old first-hit regex read "Index" out of
  # "Inflation-Indexed" for WSHONBIIA/WSHONBIIL/DFII10; fixed 2026-11-09).
  m <- str_match(html, "series-meta-observation-value\">[^<]*</span>\\s*\\|\\s*([^|<]+?)\\s*(,|\\|)")
  str_trim(m[1, 2])
}

# ---- NY Fed Markets API ---------------------------------------------------------
NYFED <- "https://markets.newyorkfed.org/api/"

.nyfed_csv <- function(path, name, start = NULL, end = NULL) {
  q <- if (!is.null(start)) paste0("?startDate=", start, "&endDate=", end %||% format(Sys.Date())) else ""
  resp <- .get_with_retry(paste0(NYFED, path, q))
  txt <- httr::content(resp, as = "text", encoding = "UTF-8")
  .cache_write(charToRaw(txt), "nyfed", name)
  read_csv(I(txt), show_col_types = FALSE, col_types = cols(.default = col_character()),
           name_repair = "minimal")
}

# rates: type in c("unsecured","secured"), rate in c("effr","obfr","sofr","bgcr","tgcr","all")
nyfed_rates <- function(path, start = "2000-07-01", end = NULL) {
  .nyfed_csv(path, paste0("rates_", gsub("[^a-z]", "_", path)), start, end) %>%
    mutate(date = mdy(`Effective Date`)) %>% relocate(date)
}
nyfed_rp_results <- function(start = "2000-01-01", end = NULL) {
  .nyfed_csv("rp/results/search.csv", "rp_results", start, end) %>%
    mutate(date = mdy(`Operation Date`)) %>% relocate(date)
}
nyfed_rp_props <- function(start = "2013-09-01", end = NULL) {
  .nyfed_csv("rp/reverserepo/propositions/search.csv", "rp_props", start, end) %>%
    mutate(date = mdy(`Operation Date`)) %>% relocate(date)
}

# ---- Treasury FiscalData ---------------------------------------------------------
fiscaldata_mspd <- function() {
  base <- "https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v1/debt/mspd/mspd_table_1"
  out <- list(); page <- 1
  repeat {
    url <- paste0(base, "?sort=record_date&page%5Bsize%5D=10000&page%5Bnumber%5D=", page)
    j <- jsonlite::fromJSON(httr::content(.get_with_retry(url), as = "text", encoding = "UTF-8"))
    out[[page]] <- as_tibble(j$data)
    if (page >= j$meta$`total-pages`) break
    page <- page + 1
  }
  df <- bind_rows(out) %>% mutate(date = as.Date(record_date)) %>% relocate(date)
  .cache_write(charToRaw(format_csv(df)), "fiscaldata", "mspd_table_1")
  df
}

# ---- static NY Fed files (legacy pipe) --------------------------------------------
read_static_manifest <- function() read_csv(pipe_path("config", "static_files.csv"), show_col_types = FALSE)

static_file <- function(file) {
  man <- read_static_manifest(); row <- man[man$file == file, ]
  stopifnot(nrow(row) == 1)
  p <- pipe_path("static", file)
  md5 <- unname(tools::md5sum(p))
  if (!identical(md5, row$md5)) stop("MD5 mismatch for ", file, ": ", md5, " vs manifest ", row$md5)
  p
}
