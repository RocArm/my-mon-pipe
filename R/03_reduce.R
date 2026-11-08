# 03_reduce.R -- daily -> weekly on the H.4.1 grid.
#   WL : value on the calendar's Wednesday-level date (last business day on/before the nominal Wednesday)
#   WA : mean over the business days of the Thu..Wed week (business-day average, not 7-day)

# Inner-join a daily long table to the business-day calendar (drops weekends, weekday holidays,
# spurious rows). Dates before the calendar start are dropped too.
to_bdays <- function(df, cal) {
  bd <- bdays_of(cal)
  df %>% inner_join(bd, by = "date")
}

daily_to_weekly <- function(df, cal, min_obs = 1) {
  check_long(df)
  # only complete weeks: the nominal Wednesday must be inside the calendar (drops the running week)
  d <- to_bdays(df, cal) %>% filter(!is.na(value), week_wed <= max(cal$date))
  wa <- d %>% group_by(series, unit, week_wed) %>%
    summarise(value = mean(value), n = n(),
              source = paste(sort(unique(source)), collapse = "+"), .groups = "drop") %>%
    filter(n >= min_obs) %>%
    transmute(date = week_wed, series, stat = "WA", value, unit, source)
  wl <- d %>% filter(date == wl_date) %>%
    transmute(date = week_wed, series, stat = "WL", value, unit, source)
  bind_rows(wa, wl) %>% arrange(series, stat, date)
}
