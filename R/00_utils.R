# 00_utils.R -- shared helpers: paths, registry, schema, units, logging, warnings
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(purrr); library(stringr)
  library(lubridate); library(httr); library(readxl); library(jsonlite)
})

# ---- paths -----------------------------------------------------------------
pipe_root <- function() {
  r <- getOption("mmp.root")
  if (is.null(r)) stop("options(mmp.root = <repo path>) must be set before sourcing the pipeline")
  r
}
pipe_path <- function(...) file.path(pipe_root(), ...)
ensure_dir <- function(p) { if (!dir.exists(p)) dir.create(p, recursive = TRUE); invisible(p) }

# ---- registry ----------------------------------------------------------------
read_registry <- function() {
  reg <- read_csv(pipe_path("config", "series_registry.csv"), show_col_types = FALSE,
                  col_types = cols(.default = col_character(), multiplier = col_double()))
  reg %>% mutate(stat = replace_na(stat, ""), end_expected = replace_na(end_expected, ""))
}
read_events <- function() {
  read_csv(pipe_path("config", "events.csv"), show_col_types = FALSE,
           col_types = cols(date = col_date(), .default = col_character()))
}

# ---- long schema -------------------------------------------------------------
# Every pipe output is a long table with exactly these columns.
LONG_COLS <- c("date", "series", "stat", "value", "unit", "source")

as_long <- function(df, series, stat = "", unit, source) {
  stopifnot(all(c("date", "value") %in% names(df)))
  tibble(date = as.Date(df$date), series = series, stat = stat,
         value = as.numeric(df$value), unit = unit, source = source)
}
check_long <- function(df) {
  stopifnot(identical(names(df)[seq_along(LONG_COLS)], LONG_COLS))
  stopifnot(inherits(df$date, "Date"), is.numeric(df$value))
  invisible(df)
}

# ---- units -------------------------------------------------------------------
# The only place a conversion factor is applied. multiplier comes from the registry.
apply_multiplier <- function(df, multiplier, target_unit) {
  df %>% mutate(value = value * multiplier, unit = target_unit)
}

# ---- logging -----------------------------------------------------------------
log_file <- function() pipe_path("data", "build_log.txt")
log_line <- function(...) {
  msg <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " | ", paste0(..., collapse = ""))
  cat(msg, "\n", sep = "")
  ensure_dir(dirname(log_file()))
  cat(msg, "\n", file = log_file(), append = TRUE, sep = "")
  invisible(msg)
}
log_series <- function(name, stat, df, unit) {
  n <- sum(!is.na(df$value))
  log_line(sprintf("%-38s %-2s %s -> %s  n=%5d  unit=%s", name, stat,
                   format(min(df$date)), format(max(df$date)), n, unit))
}

# ---- indicative-history guard --------------------------------------------------
# Any object or function touching the legacy (indicative / brokered) files calls this.
warn_indicative <- function(what) {
  msg <- paste0("INDICATIVE DATA: '", what, "' is NY Fed indicative/brokered history, a different universe ",
                "and methodology from the official series. Do not splice onto official series; keep the ",
                "'source' column visible.")
  warning(msg, call. = FALSE, immediate. = TRUE)
  log_line("WARNING ", msg)
  invisible(msg)
}

# ---- small helpers -------------------------------------------------------------
wednesday_on_or_after <- function(d) {
  # ISO weekday: Mon=1 ... Sun=7; Wednesday = 3
  d + ((3 - lubridate::wday(d, week_start = 1)) %% 7)
}
`%||%` <- function(a, b) if (is.null(a)) b else a
