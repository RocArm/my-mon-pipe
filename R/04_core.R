# 04_core.R -- the core pipe: weekly (H.4.1 Wednesday grid from 2002-12-18), FRED-only.

CORE_START <- as.Date("2002-12-18")

# Pull one registry row from FRED into the long schema (units converted, nothing else).
pull_fred_row <- function(row) {
  raw <- fred_csv(row$source_id)
  as_long(raw, series = row$name, stat = row$stat, unit = row$source_unit, source = row$source_id) %>%
    apply_multiplier(row$multiplier, row$target_unit)
}

# ---- composites (built on the daily business-day table, before weekly reduction) ------------
# target_top / target_bottom: single target before 2008-12-16 (zero-width range), range after.
# ior: IOER until 2021-07-28, IORB from 2021-07-29. IORR stays raw only.
build_composites <- function(daily) {
  pick <- function(primary, fallback, name) {
    p <- daily %>% filter(series == primary)  %>% select(date, value, unit, source)
    f <- daily %>% filter(series == fallback) %>% select(date, value, unit, source)
    bind_rows(p, f %>% anti_join(p, by = "date")) %>%
      transmute(date, series = name, stat = "", value, unit, source) %>% arrange(date)
  }
  bind_rows(
    pick("target_upper", "target_single", "target_top"),
    pick("target_lower", "target_single", "target_bottom"),
    pick("iorb", "ioer", "ior"))
}

# ---- core weekly ------------------------------------------------------------------------------
build_core <- function(reg, cal) {
  core <- reg %>% filter(pipe == "core")
  stopifnot(all(core$source == "fred"))

  log_line("== core: ", nrow(core), " registry rows")
  pulled <- map(seq_len(nrow(core)), function(i) {
    row <- core[i, ]
    df <- pull_fred_row(row)
    log_series(row$name, row$stat, df, row$target_unit)
    list(row = row, df = df)
  })

  # weekly H.4.1 rows come dated on the nominal Wednesday already
  weekly <- pulled %>% keep(~ .x$row$native_freq == "w") %>% map("df") %>% bind_rows() %>%
    filter(date >= CORE_START)
  stopifnot(all(lubridate::wday(weekly$date, week_start = 1) == 3))

  # daily rows: business-day join, composites, then WL / WA
  daily <- pulled %>% keep(~ .x$row$native_freq == "d") %>% map("df") %>% bind_rows() %>%
    to_bdays(cal) %>% select(all_of(LONG_COLS))
  # operation amounts (group OPS): FRED leaves business days without an operation blank;
  # from each series' first observation onward a blank means "no operation" -> 0.
  ops <- core %>% filter(group == "OPS") %>% pull(name)
  daily <- daily %>% group_by(series) %>%
    mutate(value = if_else(series %in% ops & is.na(value) & date >= min(date[!is.na(value)]), 0, value)) %>%
    ungroup()
  daily <- bind_rows(daily, build_composites(daily))
  daily_w <- daily_to_weekly(daily, cal) %>% filter(date >= CORE_START)

  out <- bind_rows(weekly, daily_w) %>% arrange(series, stat, date)
  check_long(out)
  log_line("== core weekly: ", nrow(out), " rows, ", n_distinct(out$series), " series, ",
           format(min(out$date)), " -> ", format(max(out$date)))
  out
}

# ---- core quarterly (as published; aligned on demand by align_quarterly) -----------------------
build_core_quarterly <- function(reg) {
  q <- reg %>% filter(pipe == "core_q")
  out <- map(seq_len(nrow(q)), function(i) {
    row <- q[i, ]; df <- pull_fred_row(row); log_series(row$name, "q", df, row$target_unit); df
  }) %>% bind_rows() %>% filter(!is.na(value)) %>% arrange(series, date)
  check_long(out)
  out
}

# ---- wide helper (analysis convenience, not storage) ----------------------------------------------
core_wide <- function(core, stat = c("WL", "WA"), grid = NULL) {
  stat <- match.arg(stat)
  w <- core %>% filter(stat == !!stat) %>% select(date, series, value) %>%
    pivot_wider(names_from = series, values_from = value) %>% arrange(date)
  if (!is.null(grid)) w <- tibble(date = grid) %>% left_join(w, by = "date")
  w
}

# ---- save -------------------------------------------------------------------------------------
save_table <- function(df, name) {
  ensure_dir(pipe_path("data"))
  saveRDS(df, pipe_path("data", paste0(name, ".rds")))
  write_csv(df, pipe_path("data", paste0(name, ".csv")))
  log_line("saved data/", name, ".rds / .csv  (", nrow(df), " rows)")
  invisible(df)
}
