# 06_aux.R -- auxiliary pipes. Native frequency is kept (daily stays daily on business days).
#   aux1  distributions      NY Fed API, daily
#   aux2  remaining H.4.1    FRED, weekly (+ H.3 reserve balances)
#   aux3  Treasury debt + H.8 FRED quarterly/weekly/monthly + FiscalData MSPD monthly
#   aux4  Treasury rates     FRED daily + monthly
#   aux5  operations         NY Fed API, operation level (wide tables, units converted)

# ---- generic FRED pipe ------------------------------------------------------------------------
build_aux_fred <- function(reg, cal, pipe) {
  rows <- reg %>% filter(pipe == !!pipe, source == "fred")
  log_line("== ", pipe, ": ", nrow(rows), " FRED rows")
  out <- map(seq_len(nrow(rows)), function(i) {
    row <- rows[i, ]
    df <- pull_fred_row(row)
    if (row$native_freq == "d") df <- to_bdays(df, cal) %>% select(all_of(LONG_COLS))
    df <- df %>% filter(!is.na(value))
    log_series(row$name, row$stat, df, row$target_unit)
    df
  }) %>% bind_rows() %>% arrange(series, stat, date)
  check_long(out)
}

# ---- aux3: FiscalData MSPD table 1 ---------------------------------------------------------------
# series = mspd_<type>_<class>, stat = public | intragov | total, usd_mn
build_mspd <- function() {
  raw <- fiscaldata_mspd()
  slug <- function(x) x %>% str_to_lower() %>% str_replace_all("[^a-z0-9]+", "_") %>% str_replace_all("^_|_$", "")
  df <- raw %>%
    mutate(series = paste0("mspd_", slug(security_type_desc),
                           if_else(security_class_desc == "_", "", paste0("_", slug(security_class_desc))))) %>%
    select(date, series, public = debt_held_public_mil_amt, intragov = intragov_hold_mil_amt, total = total_mil_amt) %>%
    pivot_longer(c(public, intragov, total), names_to = "stat", values_to = "value") %>%
    mutate(value = suppressWarnings(as.numeric(value)), unit = "usd_mn", source = "fiscaldata:mspd_table_1") %>%
    filter(!is.na(value)) %>% select(all_of(LONG_COLS)) %>% arrange(series, stat, date)
  log_line(sprintf("%-38s %-2s %s -> %s  n=%5d  unit=usd_mn  (%d series)", "mspd_table1", "", format(min(df$date)),
                   format(max(df$date)), nrow(df), n_distinct(df$series)))
  check_long(df)
}

build_aux3 <- function(reg, cal) bind_rows(build_aux_fred(reg, cal, "aux3"), build_mspd()) %>% arrange(series, stat, date)

# ---- aux1: NY Fed rate distributions -------------------------------------------------------------
# One API row per rate per day. Long: series = dist_<rate>, stat in
#   rate p1 p25 p75 p99 (bp) | volume (usd_mn) | target_from target_to intraday_low intraday_high std_dev (bp) | revised (0/1)
.stat_map <- c("Rate (%)" = "rate", "1st Percentile (%)" = "p1", "25th Percentile (%)" = "p25",
               "75th Percentile (%)" = "p75", "99th Percentile (%)" = "p99", "Volume ($Billions)" = "volume",
               "Target Rate From (%)" = "target_from", "Target Rate To (%)" = "target_to",
               "Intra Day - Low (%)" = "intraday_low", "Intra Day - High (%)" = "intraday_high",
               "Standard Deviation (%)" = "std_dev")

build_aux1 <- function(reg, cal) {
  rows <- reg %>% filter(pipe == "aux1")
  log_line("== aux1: ", nrow(rows), " NY Fed rate series")
  out <- map(seq_len(nrow(rows)), function(i) {
    row <- rows[i, ]
    raw <- nyfed_rates(row$source_id, start = row$start_expected)
    rev_col <- names(raw)[str_detect(str_to_lower(names(raw)), "revision")]
    keep <- intersect(names(.stat_map), names(raw))
    long <- raw %>% select(date, all_of(keep), all_of(rev_col)) %>%
      mutate(across(all_of(keep), ~ suppressWarnings(as.numeric(.x)))) %>%
      pivot_longer(all_of(keep), names_to = "col", values_to = "value") %>%
      mutate(stat = unname(.stat_map[col]),
             unit = if_else(stat == "volume", "usd_mn", "bp"),
             value = if_else(stat == "volume", value * 1000, value * 100)) %>%
      filter(!is.na(value)) %>% transmute(date, series = row$name, stat, value, unit, source = paste0("nyfed:", row$source_id))
    if (length(rev_col)) {
      rv <- raw %>% transmute(date, series = row$name, stat = "revised",
                              value = as.numeric(!is.na(.data[[rev_col[1]]]) & nchar(.data[[rev_col[1]]]) > 0),
                              unit = "flag", source = paste0("nyfed:", row$source_id))
      long <- bind_rows(long, rv)
    }
    long <- to_bdays(long, cal) %>% select(all_of(LONG_COLS))   # drops the 2003-07-20 Sunday row etc.
    log_series(row$name, "", long, "bp/usd_mn")
    long
  }) %>% bind_rows() %>% arrange(series, stat, date)
  check_long(out)
}

# ---- aux5: operations (wide, operation level) ---------------------------------------------------
# All "($Billions)" columns -> x1000 and renamed "(usd_mn)"; all "(%)" / "Rate" columns -> x100 "(bp)".
.convert_ops_cols <- function(df) {
  num <- function(x) suppressWarnings(as.numeric(x))
  bn <- names(df)[str_detect(names(df), fixed("($Billions)"))]
  # "(%)" columns are rates, except "Amt At Stop-Out (%)" which is an allotment share: kept in percent
  pc <- names(df)[str_detect(names(df), "\\(%\\)") & !str_detect(names(df), "Amt At Stop-Out") & !names(df) %in% bn]
  sh <- names(df)[str_detect(names(df), "Amt At Stop-Out")]
  for (c in bn) df[[c]] <- num(df[[c]]) * 1000
  for (c in pc) df[[c]] <- num(df[[c]]) * 100
  for (c in sh) df[[c]] <- num(df[[c]])
  names(df)[names(df) %in% bn] <- str_replace(names(df)[names(df) %in% bn], fixed("($Billions)"), "(usd_mn)")
  names(df)[names(df) %in% pc] <- paste0(str_replace(names(df)[names(df) %in% pc], "\\s*\\(%\\)$", ""), " (bp)")
  names(df)[names(df) %in% sh] <- str_replace(names(df)[names(df) %in% sh], "\\s*\\(%\\)$", " (pct_share)")
  df
}
build_aux5 <- function(reg, cal) {
  res <- nyfed_rp_results(start = "2000-01-01") %>% .convert_ops_cols() %>% arrange(date)
  prp <- nyfed_rp_props(start = "2013-09-01") %>% .convert_ops_cols() %>% arrange(date)
  log_line(sprintf("%-38s    %s -> %s  n=%5d  (operation level)", "ops_results", format(min(res$date)), format(max(res$date)), nrow(res)))
  log_line(sprintf("%-38s    %s -> %s  n=%5d  (operation level)", "ops_rrp_by_counterparty", format(min(prp$date)), format(max(prp$date)), nrow(prp)))
  list(results = res, rrp_by_counterparty = prp)
}
