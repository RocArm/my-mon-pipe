# run_tests.R -- plain-R checks on the built tables. Any failure stops with an error.
#   Rscript tests/run_tests.R [--units]     (--units also re-reads each FRED series page; slow)
args <- commandArgs(trailingOnly = TRUE)
f <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))])
root <- if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
options(mmp.root = root)
for (s in sort(list.files(file.path(root, "R"), full.names = TRUE))) source(s)

ok <- function(cond, msg) { if (!isTRUE(cond)) stop("TEST FAILED: ", msg, call. = FALSE); cat("ok  ", msg, "\n") }
load_if <- function(name) { p <- pipe_path("data", paste0(name, ".rds")); if (file.exists(p)) readRDS(p) else NULL }

reg  <- read_registry()
cal  <- load_if("calendar"); core <- load_if("core_weekly"); coreq <- load_if("core_quarterly")
aux  <- list(aux1 = load_if("aux1_distributions"), aux2 = load_if("aux2_h41_rest"), aux3 = load_if("aux3_debt_h8"),
             aux4 = load_if("aux4_treasury_rates"), aux5 = load_if("aux5_operations"))
legacy <- load_if("legacy_indicative")

# ---------------------------------------------------------------- calendar
ok(!is.null(cal), "calendar exists")
ok(sum(cal$is_bday & wday(cal$date, week_start = 1) > 5) == 0, "calendar: no weekend business days")
ok(all(cal$wl_date[cal$is_bday] %in% cal$date[cal$is_bday]), "calendar: every Wednesday-level date is a business day")
ok(all(wday(cal$week_wed, week_start = 1) == 3), "calendar: week ids are Wednesdays")
full_years <- setdiff(unique(cal$year), range(cal$year))
cnt <- cal %>% filter(year %in% full_years) %>% group_by(year) %>%
  summarise(m = sum(is_last_bday_month), q = sum(is_last_bday_quarter), y = sum(is_last_bday_year), .groups = "drop")
ok(all(cnt$m == 12 & cnt$q == 4 & cnt$y == 1), "calendar: 12/4/1 period-end business days per full year")
gaps <- diff(cal$date[cal$is_bday]); ok(max(as.numeric(gaps)) <= 5, "calendar: no business-day gap longer than 5 days")
ok(min(cal$date) == as.Date("2000-07-03"), "calendar: starts 2000-07-03")

# ---------------------------------------------------------------- events config
ev <- read_csv(pipe_path("config", "events.csv"), show_col_types = FALSE, col_types = cols(.default = col_character()))
ok(identical(names(ev), c("date", "event_type", "memo", "source", "confidence")), "events.csv: schema date,event_type,memo,source,confidence")
ok(all(!is.na(as.Date(ev$date, format = "%Y-%m-%d"))), "events.csv: all dates parse as YYYY-MM-DD")
ok(!any(duplicated(ev[c("date", "event_type")])), "events.csv: no duplicate date/event_type")
ok(all(ev$confidence %in% c("high", "medium", "low")), "events.csv: confidence in high/medium/low")
ok(all(nchar(ev$source) > 0), "events.csv: every row has a source")
ok(all(as.Date(ev$date) <= max(cal$date)), "events.csv: no future dates")
ev_dates <- unique(as.Date(ev$date)); ev_dates <- ev_dates[ev_dates >= min(cal$date) & ev_dates <= max(cal$date)]
ok(sum(!is.na(cal$event)) == length(ev_dates), sprintf("calendar: every event date inside the calendar is joined (%d dates)", length(ev_dates)))
ok(!any(ev$event_type %in% c("policy_rate_regime", "on_rrp", "recession")), "events.csv: dropped types (policy_rate_regime, on_rrp, recession) are absent")

# ---------------------------------------------------------------- episodes config
ep <- read_csv(pipe_path("config", "episodes.csv"), show_col_types = FALSE, col_types = cols(.default = col_character()))
ok(identical(names(ep), c("kind", "label", "start", "end", "basis", "source", "confidence")), "episodes.csv: schema kind,label,start,end,basis,source,confidence")
ok(all(!is.na(as.Date(ep$start))), "episodes.csv: all starts parse")
open_ended <- is.na(ep$end) | ep$end == ""
ok(all(as.Date(ep$end[!open_ended]) >= as.Date(ep$start[!open_ended])), "episodes.csv: end >= start")
ok(sum(open_ended) == 1 && ep$kind[open_ended] == "rmp", "episodes.csv: exactly one open-ended episode (reserve-management bills 2)")
for (k in unique(ep$kind)) {            # no overlap within a kind (the calendar column holds one label)
  e <- ep %>% filter(kind == k) %>% mutate(s = as.Date(start), e = if_else(end == "" | is.na(end), max(cal$date), as.Date(end))) %>% arrange(s)
  ok(all(e$s[-1] > e$e[-nrow(e)]) || nrow(e) == 1, paste0("episodes.csv: no overlapping episodes within kind ", k))
}
ok(all(paste0("ep_", unique(ep$kind)) %in% names(cal)), "calendar: one ep_<kind> column per episode kind")
ok(!is.na(cal$ep_qe[cal$date == as.Date("2013-06-19")]) && cal$ep_qe[cal$date == as.Date("2013-06-19")] == "QE3", "calendar: 2013-06-19 falls in QE3")
ok(is.na(cal$ep_qe[cal$date == as.Date("2016-06-29")]), "calendar: 2016-06-29 is in no QE episode")
ok(!is.na(cal$ep_rmp[max(which(cal$is_bday))]), "calendar: open-ended RMP episode reaches the last business day")

# ---------------------------------------------------------------- core schema and grid
ok(!is.null(core), "core_weekly exists")
check_long(core); ok(TRUE, "core: long schema")
ok(min(core$date) == as.Date("2002-12-18"), "core: grid starts 2002-12-18")
ok(all(wday(core$date, week_start = 1) == 3), "core: all dates are Wednesdays")
ok(max(core$date) <= max(cal$date), "core: no partial running week")
ok(all(core$unit %in% c("usd_mn", "bp")), "core: units are usd_mn or bp only")
ok(all(core$stat %in% c("WA", "WL")), "core: stats are WA/WL only")
ok(!any(duplicated(core[c("date", "series", "stat")])), "core: no duplicate date/series/stat")

# ---------------------------------------------------------------- core_daily
cored <- load_if("core_daily")
ok(!is.null(cored), "core_daily exists")
check_long(cored); ok(TRUE, "core_daily: long schema")
ok(min(cored$date) == as.Date("2002-12-18"), "core_daily: starts 2002-12-18")
ok(all(cored$date %in% cal$date[cal$is_bday]), "core_daily: every date is a calendar business day")
ok(all(cored$stat == ""), "core_daily: stat is empty (native daily value)")
ok(all(cored$unit %in% c("usd_mn", "bp")), "core_daily: units are usd_mn or bp only")
ok(!any(duplicated(cored[c("date", "series")])), "core_daily: no duplicate date/series")
daily_series <- unique(cored$series)
ok(all(c("effr", "target_top", "target_bottom", "ior", "primary_credit_rate", "on_rrp_overnight_tsy") %in% daily_series), "core_daily: expected series present")
ok(!any(daily_series %in% c("reserve_balances", "tga")), "core_daily: no weekly H.4.1 series")
# weekly WL must equal the daily value on the calendar's Wednesday-level date, for every daily series
wlmap <- cal %>% filter(is_bday) %>% distinct(week_wed, wl_date)
chk <- core %>% filter(stat == "WL", series %in% daily_series) %>% select(date, series, wl = value) %>%
  inner_join(wlmap, by = c("date" = "week_wed")) %>%
  inner_join(cored %>% select(wl_date = date, series, d = value), by = c("wl_date", "series"))
ok(nrow(chk) > 10000 && max(abs(chk$wl - chk$d)) < 1e-9, sprintf("core: weekly WL equals core_daily on the Wednesday-level date (%d checks)", nrow(chk)))
# daily composites continuous
dz <- cored %>% filter(series %in% c("target_top", "target_bottom", "ior")) %>% count(series)
ok(all(dz$n[dz$series != "ior"] == n_distinct(cored$date)), "core_daily: target composites defined on every business day")

# ---------------------------------------------------------------- core identities (H.4.1 lines)
wide <- function(df, st) df %>% filter(stat == st) %>% select(date, series, value) %>% pivot_wider(names_from = series, values_from = value)
for (st in c("WL", "WA")) {
  x <- wide(core, st)
  ok(max(abs(x$factors_supplying_total - x$factors_absorbing_ex_reserves - x$reserve_balances), na.rm = TRUE) <= 5,
     paste0("core ", st, ": supplying = absorbing + reserve balances (<= 5 $mn rounding)"))
  ok(max(abs(x$rrp_total - x$rrp_foreign_official - x$on_rrp_others), na.rm = TRUE) <= 5,
     paste0("core ", st, ": RRP total = foreign official + others"))
  # WA is a 7-calendar-day carry-forward mean (D8), the same construct as the H.4.1 week average,
  # so the stock >= overnight inequality must hold for both statistics.
  # Two known WA exceptions (weeks of 2018-02-21 and 2023-01-11) where the published H.4.1 week average sits
  # below the 7-day mean of the daily amounts by 8 $bn and 0.5 $bn; the WL agrees in both. Tolerance 0.5 %.
  viol <- which(x$on_rrp_others - x$on_rrp_overnight_tsy < -5)
  ok(length(viol) <= ceiling(0.005 * nrow(x)),
     sprintf("core %s: H.4.1 ON RRP stock >= FRED overnight amount (difference = term ops); exceptions: %s",
             st, if (length(viol)) paste(format(x$date[viol]), collapse = ", ") else "none"))
  y <- x %>% filter(date >= as.Date("2013-09-25"))
  share <- mean(abs(y$on_rrp_others - y$on_rrp_overnight_tsy) <= 5, na.rm = TRUE)
  ok(share >= 0.9, sprintf("core %s: overnight ON RRP equals H.4.1 line in %.0f%% of weeks since 2013-09-25 (>= 90%%)", st, 100 * share))
}
# WA construct check on a step series: WA differs from WL only in weeks with an intra-week change
x <- core %>% filter(series == "target_top") %>% select(date, stat, value) %>% pivot_wider(names_from = stat, values_from = value)
chg <- cored %>% filter(series == "target_top") %>% arrange(date) %>% mutate(ch = value != lag(value)) %>% filter(ch) %>%
  inner_join(cal %>% select(date, week_wed), by = "date") %>% distinct(week_wed)
diff_weeks <- x$date[abs(x$WA - x$WL) > 1e-9]
ok(all(diff_weeks %in% chg$week_wed), "core: target_top WA != WL only in weeks containing a target change")

# ---------------------------------------------------------------- units: magnitude bands
med <- core %>% filter(date >= as.Date("2020-01-01")) %>% group_by(series, unit) %>% summarise(m = median(value, na.rm = TRUE), .groups = "drop")
ok(all(med$m[med$unit == "bp"] >= 0 & med$m[med$unit == "bp"] <= 1000), "core: rates in bp lie in 0..1000 since 2020")
big <- c("reserve_balances", "currency_in_circulation", "securities_held_outright", "total_assets_fed", "factors_supplying_total")
ok(all(med$m[med$series %in% big] > 1e6), "core: major H.4.1 lines exceed 1e6 $mn since 2020 (i.e. are in millions, not billions)")

# ---------------------------------------------------------------- official start dates (splice rule)
starts <- core %>% group_by(series) %>% summarise(first = min(date), .groups = "drop")
first_of <- function(s) starts$first[starts$series == s]
ok(first_of("sofr") >= as.Date("2018-04-04"), "core: SOFR starts no earlier than the week of 2018-04-03")
ok(first_of("obfr") >= as.Date("2016-03-02"), "core: OBFR starts no earlier than the week of 2016-03-01")
ok(first_of("on_rrp_rate") >= as.Date("2013-09-25"), "core: ON RRP rate starts no earlier than the week of 2013-09-23")
ok(!any(grepl("^ind_", core$series)), "core: no indicative series")
for (nm in names(aux)) if (!is.null(aux[[nm]]) && "series" %in% names(aux[[nm]]))
  ok(!any(grepl("^ind_", aux[[nm]]$series)), paste0(nm, ": no indicative series"))
if (!is.null(legacy)) ok(all(grepl("^ind_", legacy$series)), "legacy: every series carries the ind_ prefix")

# ---------------------------------------------------------------- composites
x <- wide(core, "WL")
ok(all(x$target_top[x$date < as.Date("2008-12-17")] == x$target_bottom[x$date < as.Date("2008-12-17")]), "core: zero-width target range before 2008-12-16")
ok(all(x$target_top[x$date >= as.Date("2008-12-17")] - x$target_bottom[x$date >= as.Date("2008-12-17")] == 25), "core: 25 bp target range from 2008-12-17")
ok(all(!is.na(x$ior[x$date >= as.Date("2008-10-15")])), "core: ior composite has no gap from 2008-10-15")

# ---------------------------------------------------------------- quarterly + alignment
ok(!is.null(coreq) && all(c("ngdp", "ngdp_potential") %in% coreq$series), "core_quarterly: both GDP series present")
ok(max(coreq$date[coreq$series == "ngdp_potential"]) >= as.Date("2030-01-01"), "core_quarterly: potential GDP carries projections")
a0 <- align_quarterly(coreq, weekly_grid(cal))
ok(!any(a0$extended) && any(is.na(a0$value[a0$series == "ngdp"])) && all(!is.na(a0$value[a0$series == "ngdp_potential"])),
   "align: default (extend = FALSE) leaves the GDP tail NA and never flags extended")
a <- align_quarterly(coreq, weekly_grid(cal), extend = TRUE)
ok(all(!is.na(a$value[a$series == "ngdp"])), "align: extend = TRUE defines GDP on the whole weekly grid")
ok(any(a$extended[a$series == "ngdp"]) && !any(a$extended[a$series == "ngdp_potential"]), "align: only actual GDP is extended")
ok(identical(a0$value[!a0$extended & !is.na(a0$value)], a$value[!a$extended & !is.na(a0$value)]), "align: extension changes only the tail")
b <- align_quarterly(coreq, weekly_grid(cal), method = "step"); ok(all(!b$extended), "align: step never extends")

# ---------------------------------------------------------------- aux1 vs FRED: published rates and calendar
# The NY Fed API rate (aux1) must equal the FRED daily copy, in bp, on every common business day,
# and every calendar business day must be a NY Fed EFFR publication date.
latest_raw <- function(id) tail(sort(list.files(pipe_path("data", "raw", "fred"), pattern = paste0("^", id, "_[0-9]{8}[.]csv$"), full.names = TRUE)), 1)
if (!is.null(aux$aux1) && length(latest_raw("EFFR"))) {
  for (p in list(c("EFFR", "dist_effr"), c("OBFR", "dist_obfr"), c("SOFR", "dist_sofr"))) {
    fr <- read_csv(latest_raw(p[1]), show_col_types = FALSE, na = c(".", ""),
                   col_types = cols(observation_date = col_date(), .default = col_double()))
    names(fr) <- c("date", "fred"); fr <- fr %>% mutate(fred = fred * 100) %>% to_bdays(cal) %>% select(date, fred)
    api <- aux$aux1 %>% filter(series == p[2], stat == "rate") %>% select(date, api = value)
    j <- inner_join(fr, api, by = "date")
    ok(nrow(j) > 1000 && max(abs(j$api - j$fred)) < 1e-9, sprintf("aux1 vs FRED: %s identical on all %d common days", p[1], nrow(j)))
  }
  api_days <- aux$aux1 %>% filter(series == "dist_effr", stat == "rate") %>% pull(date)
  # compare only up to the API table's last date (the calendar may have been rebuilt later than aux1)
  extra <- setdiff(cal$date[cal$is_bday & cal$date <= max(api_days)], api_days); extra <- as.Date(extra, origin = "1970-01-01")
  ok(length(extra) == 0, paste0("calendar: every business day is a NY Fed EFFR publication date (FRED-only dates: ", paste(format(extra), collapse = ", "), ")"))
}

# ---------------------------------------------------------------- registry coverage (what was built)
long_aux <- aux[map_lgl(aux, ~ !is.null(.x) && "series" %in% names(.x))]
built <- bind_rows(core %>% mutate(pipe = "core"), coreq %>% mutate(pipe = "core_q"),
                   imap(long_aux, ~ mutate(.x, pipe = .y)) %>% bind_rows(),
                   if (!is.null(legacy)) legacy %>% mutate(pipe = "legacy"))
built_pipes <- unique(built$pipe)
# FRED and NY Fed rate rows: registry name must appear as a series in its pipe
want <- reg %>% filter(pipe %in% built_pipes, source %in% c("fred", "nyfed_rates"))
have <- built %>% distinct(pipe, series)
missing <- want %>% anti_join(have, by = c("pipe", "name" = "series"))
ok(nrow(missing) == 0, paste0("registry: every FRED / NY Fed rate row of built pipes produced output (missing: ", paste(missing$name, collapse = ", "), ")"))
# other sources: presence checks
if ("aux3" %in% built_pipes) ok(any(startsWith(have$series[have$pipe == "aux3"], "mspd_")), "registry: FiscalData MSPD produced mspd_* series in aux3")
if (!is.null(legacy)) ok(all(c("ind_tgcr", "ind_bgcr", "ind_sofr", "ind_effr_brokered", "ind_sofr_averages") %in% legacy$series), "registry: legacy files produced all five ind_ series")
ops <- load_if("aux5_operations"); prp <- load_if("aux5_rrp_by_counterparty")
if (!is.null(ops)) ok(nrow(ops) > 8000 && any(grepl("\\(usd_mn\\)", names(ops))) && !any(grepl("Billions", names(ops))), "aux5: operation results present, amounts converted to usd_mn")
if (!is.null(prp)) ok(nrow(prp) > 3000 && !any(grepl("Billions", names(prp))), "aux5: ON RRP by counterparty present, amounts converted to usd_mn")

# ---------------------------------------------------------------- optional: FRED unit drift
if ("--units" %in% args) {
  fr <- reg %>% filter(source == "fred", pipe %in% built_pipes) %>% distinct(source_id, source_unit)
  expect <- c(usd_mn = "Millions of", usd_bn = "Billions of", pct = "Percent")
  bad <- character()
  for (i in seq_len(nrow(fr))) {
    u <- tryCatch(fred_units(fr$source_id[i]), error = function(e) NA)
    if (is.na(u) || !startsWith(u, expect[[fr$source_unit[i]]])) bad <- c(bad, paste0(fr$source_id[i], "=", u))
    Sys.sleep(0.2)
  }
  ok(length(bad) == 0, paste0("FRED unit drift: all series pages match the registry unit (mismatch: ", paste(bad, collapse = "; "), ")"))
}

cat("\nALL TESTS PASSED\n")
