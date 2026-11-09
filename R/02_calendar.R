# 02_calendar.R -- the daily business-day calendar every pipe joins to.
# Anchor: dates on which FRED has a non-missing EFFR (= NY Fed publication dates), from 2000-07-03,
# minus config/calendar_exclusions.csv (FRED-only dates) plus config/calendar_inclusions.csv (NY Fed
# publication days FRED's copy leaves blank). Both lists were verified against the Markets API.

build_calendar <- function(effr = NULL, start = as.Date("2000-07-03")) {
  if (is.null(effr)) effr <- fred_csv("EFFR")
  bdays <- effr %>% filter(!is.na(value), date >= start) %>% pull(date)
  bdays <- bdays[lubridate::wday(bdays, week_start = 1) <= 5]   # defensive: drop any weekend row
  # dates FRED carries but the NY Fed never published (verified against the Markets API), see config
  excl <- tryCatch(read_csv(pipe_path("config", "calendar_exclusions.csv"), show_col_types = FALSE,
                            col_types = cols(date = col_date(), .default = col_character())), error = function(e) NULL)
  if (!is.null(excl) && nrow(excl)) {
    log_line("calendar: excluding ", nrow(excl), " FRED-only date(s): ", paste(format(excl$date), collapse = ", "))
    bdays <- setdiff(bdays, excl$date); bdays <- as.Date(bdays, origin = "1970-01-01")
  }
  # NY Fed publication days on which FRED's EFFR is blank (verified against the Markets API), see config
  incl <- tryCatch(read_csv(pipe_path("config", "calendar_inclusions.csv"), show_col_types = FALSE,
                            col_types = cols(date = col_date(), .default = col_character())), error = function(e) NULL)
  if (!is.null(incl) && nrow(incl)) {
    incl <- incl %>% filter(date >= start, lubridate::wday(date, week_start = 1) <= 5)
    log_line("calendar: including ", nrow(incl), " NY Fed-only date(s): ", paste(format(incl$date), collapse = ", "))
    bdays <- sort(unique(c(bdays, incl$date)))
  }
  end <- max(bdays)

  cal <- tibble(date = seq(start, end, by = "day")) %>%
    mutate(is_bday  = date %in% bdays,
           week_wed = wednesday_on_or_after(date),            # H.4.1 week id: Thu .. Wed, nominal Wednesday
           year = year(date), month = month(date), quarter = quarter(date))

  # Wednesday-level date: last business day on or before the nominal Wednesday, inside the week
  wl <- cal %>% filter(is_bday) %>% group_by(week_wed) %>% summarise(wl_date = max(date), .groups = "drop")
  cal <- cal %>% left_join(wl, by = "week_wed")

  # period-end / period-start flags on business days
  flag <- function(df, ..., name_last, name_first) {
    df %>% group_by(...) %>%
      mutate("{name_last}"  := is_bday & date == max(date[is_bday]),
             "{name_first}" := is_bday & date == min(date[is_bday])) %>% ungroup()
  }
  cal <- cal %>%
    flag(year, month,   name_last = "is_last_bday_month",   name_first = "is_first_bday_month") %>%
    flag(year, quarter, name_last = "is_last_bday_quarter", name_first = "is_first_bday_quarter") %>%
    flag(year,          name_last = "is_last_bday_year",    name_first = "is_first_bday_year")

  # the final partial month/quarter/year has no true "last business day" yet
  last_full_month <- floor_date(end, "month") - 1
  cal <- cal %>% mutate(
    is_last_bday_month   = is_last_bday_month   & date <= last_full_month,
    is_last_bday_quarter = is_last_bday_quarter & date <= floor_date(end, "quarter") - 1,
    is_last_bday_year    = is_last_bday_year    & date <= floor_date(end, "year") - 1)

  # week-level flags: does the Thu..Wed week contain a period end?
  wk <- cal %>% group_by(week_wed) %>%
    summarise(week_has_month_end   = any(is_last_bday_month),
              week_has_quarter_end = any(is_last_bday_quarter),
              week_has_year_end    = any(is_last_bday_year), .groups = "drop")
  cal <- cal %>% left_join(wk, by = "week_wed")

  # events (separate config), collapsed to one string per date
  ev <- tryCatch(read_events(), error = function(e) NULL)
  if (!is.null(ev) && nrow(ev)) {
    ev <- ev %>% group_by(date) %>% summarise(event = paste(event_type, memo, sep = ": ", collapse = "; "), .groups = "drop")
    cal <- cal %>% left_join(ev, by = "date")
  } else cal$event <- NA_character_

  # episodes (intervals), one column per kind holding the episode label on days inside it.
  # Read from config/episodes.csv only; config/episodes_draft.csv is the review copy and is ignored.
  ep_path <- pipe_path("config", "episodes.csv")
  if (file.exists(ep_path)) {
    ep <- read_csv(ep_path, show_col_types = FALSE, col_types = cols(.default = col_character())) %>%
      mutate(start = as.Date(start), end = if_else(is.na(end) | end == "", max(cal$date), as.Date(end)))
    for (k in unique(ep$kind)) {
      col <- paste0("ep_", k); cal[[col]] <- NA_character_
      for (i in which(ep$kind == k)) {
        inside <- cal$date >= ep$start[i] & cal$date <= ep$end[i]
        cal[[col]][inside] <- ep$label[i]
      }
    }
    log_line("calendar: joined ", nrow(ep), " episodes of kinds ", paste(unique(ep$kind), collapse = ", "))
  }

  cal %>% select(date, is_bday, week_wed, wl_date, year, quarter, month,
                 starts_with("is_first_"), starts_with("is_last_"), starts_with("week_has_"), event, starts_with("ep_"))
}

# business days only
bdays_of <- function(cal) cal %>% filter(is_bday) %>% select(date, week_wed, wl_date)

# weekly grid of nominal Wednesdays, optionally from a given start
weekly_grid <- function(cal, start = as.Date("2002-12-18")) {
  cal %>% distinct(week_wed) %>% filter(week_wed >= start, week_wed <= max(cal$date)) %>% pull(week_wed)
}
