# 03_reduce.R -- daily -> weekly on the H.4.1 grid.
#   WL : value on the calendar's Wednesday-level date (last business day on/before the nominal Wednesday)
#   WA : mean over the 7 calendar days of the Thu..Wed week, each non-business day carrying the last
#        business-day value (the H.4.1 and H.15 convention; decision D8, revised 2026-11-09). On a
#        typical week this carries two days; an overnight amount dealt on Friday counts Fri, Sat, Sun.
#        A week needs all 7 days covered (i.e. the series has started before the week) to get a WA.
#        The carry-forward is bounded by the series' last observation: a discontinued series (DFEDTAR,
#        IOER, IORR) gets no WA after the week of its last value (fixed 2026-11-09; the unbounded
#        version carried the last value to the present).

# Inner-join a daily long table to the business-day calendar (drops weekends, weekday holidays,
# spurious rows). Dates before the calendar start are dropped too.
to_bdays <- function(df, cal) {
  bd <- bdays_of(cal)
  df %>% inner_join(bd, by = "date")
}

daily_to_weekly <- function(df, cal) {
  check_long(df)
  # only complete weeks: the nominal Wednesday must be inside the calendar (drops the running week)
  d <- to_bdays(df, cal) %>% filter(!is.na(value), week_wed <= max(cal$date))
  wl <- d %>% filter(date == wl_date) %>%
    transmute(date = week_wed, series, stat = "WL", value, unit, source)

  # 7-calendar-day average with carry-forward over non-business days
  days <- cal %>% filter(week_wed <= max(cal$date)) %>% select(date, week_wed)
  wa <- d %>% select(date, series, unit, value, source) %>%
    group_by(series, unit) %>%
    group_modify(function(x, key) {
      f <- days %>% filter(date >= min(x$date), date <= max(x$date)) %>%
        left_join(x %>% select(date, value, source), by = "date") %>%
        arrange(date) %>%
        mutate(value = zoo::na.locf(value, na.rm = FALSE), source = zoo::na.locf(source, na.rm = FALSE))
      f %>% group_by(week_wed) %>%
        summarise(n = sum(!is.na(value)), value = mean(value),
                  source = paste(sort(unique(na.omit(source))), collapse = "+"), .groups = "drop") %>%
        filter(n == 7)
    }) %>% ungroup() %>%
    transmute(date = week_wed, series, stat = "WA", value, unit, source)
  bind_rows(wa, wl) %>% arrange(series, stat, date)
}
