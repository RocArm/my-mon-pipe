# =====================================================================================================
# year_quarter_ends.R
#
# How money-market rates and volumes behave around quarter ends and year ends, 2009 onward, and
# whether that depends on how abundant reserves are. A worked example of using the pipeline's
# built tables together: the calendar, the core daily / weekly / quarterly tables and two auxiliary
# pipes.
#
# BEFORE RUNNING: the script reads the pipeline's built tables from data/. They are not in the repo;
# build them first (downloads from FRED, the NY Fed and Treasury):
#
#     Rscript scripts/make_all.R             # once, about 1-2 minutes
#     Rscript exercise/year_quarter_ends.R   # about 20 seconds
#
# Run from anywhere; the repo root is found from the script's own path.
# Output: a printed log, seven CSVs in exercise/output/, eight figures in exercise/figures/
# (documented in exercise/FIGURES.md) and a page showing all figures (exercise/figures/contact_sheet.html).
#
# -----------------------------------------------------------------------------------------------------
# PIPELINE TABLES AND FUNCTIONS USED
#
#   calendar.rds             business days, last business day of quarter / year, FOMC meeting dates,
#                            policy episodes (ep_*, carried into the CSVs for reference)
#   core_daily.rds           EFFR, SOFR, IOR composite; ON RRP award rate (data-trap note only)
#   core_weekly.rds          reserve balances, currency in circulation; core_wide(core, "WL") gives
#                            Wednesday levels, one column each
#   core_quarterly.rds       nominal GDP; align_quarterly() interpolates it to any set of dates
#   aux1_distributions.rds   NY Fed percentiles, published rates and volumes of EFFR (FR 2420) and SOFR
#   aux3_debt_h8.rds         H.8 deposits and total assets of commercial banks (log and CSVs only)
#   pipe_path(), ensure_dir() file locations inside the repo
#
# -----------------------------------------------------------------------------------------------------
# SECTIONS
#
#   0. Setup               load the pipeline's functions and tables; settings
#   1. Events              last business day of each quarter, the window and benchmark days  [calendar]
#   2. Spreads             EFFR and SOFR, each minus IOR, in bp                             [core_daily]
#   3. Event panel         each spread on each window day against its benchmark
#   4. Reserve supply      reserves going into each event, relative to GDP and more  [core_weekly,
#                                                                                    core_quarterly, aux3]
#   5. Rate distribution   dispersion and quartiles of the EFFR / SOFR distributions        [aux1]
#   6. Volumes             fed funds and SOFR volume on window days against the benchmark   [aux1]
#   7. Figures
#   8. CSVs and checks
#
# MAIN TABLES
#   events   one row per event: event_date, category ("year_end" / "quarter_end"), idx = position
#            among business days
#   window   event x offset, offset -2..+2 business days: the days studied
#   bench    event x offset, offset -12..-3: the two weeks before the window
#   sp       business day x series: spread to IOR (bp), dchg = change from the previous business day
#   panel    window joined to sp: spread, bench = mean spread over the benchmark days, dev = spread - bench
#   supply   one row per event: reserves and denominators on the last H.4.1 Wednesday before the event
#
# DATA TRAPS (see also README.md at the repo root, "Caveats a user must know")
#   - on_rrp_rate is the ON RRP award rate, blank on days nobody used the facility. Not used here;
#     section 2 counts the blanks and checks that a previous-day fill would be safe.
#   - SOFR is not published on SIFMA closures (Good Friday 2021-04-02 and 2024-03-29 fall in windows);
#     left NA.
#   - GDP for the latest events comes from align_quarterly(extend = TRUE), flagged gdp_extended; see the
#     same README section ("Interpolated GDP") and docs/DECISIONS.md, D11 and D12.
# =====================================================================================================


# =====================================================================================================
# 0. SETUP
# =====================================================================================================

# Repo root from the script's path; load the pipeline's functions (R/*.R)
args <- commandArgs(trailingOnly = FALSE)
script_file <- sub("^--file=", "", args[grepl("^--file=", args)])
root <- if (length(script_file)) normalizePath(file.path(dirname(script_file), "..")) else normalizePath(".")
options(mmp.root = root)
for (s in sort(list.files(file.path(root, "R"), full.names = TRUE))) source(s)

suppressPackageStartupMessages(library(ggplot2))
options(width = 200)                                     # wide console: printed tables do not wrap

out_dir <- ensure_dir(file.path(root, "exercise", "output"))
fig_dir <- ensure_dir(file.path(root, "exercise", "figures"))

# Log helpers. The log prints compact summaries; the full tables are in the CSVs (section 8).
say  <- function(...) cat(paste0(..., collapse = ""), "\n", sep = "")                     # print a line
hr   <- function(t) cat("\n", t, "\n", strrep("-", nchar(t)), "\n", sep = "")            # section heading
fmt  <- function(x) formatC(round(x, 1) + 0, digits = 1, format = "f")                     # 1 decimal, no -0.0
pct  <- function(x) paste0(round(100 * x), "%")                                            # share as %
show <- function(df) print(as.data.frame(df), row.names = FALSE)                           # print a table

# by_offset(): one column per window day (t-2 .. t+2) holding one summary statistic
by_offset <- function(df, value, ...) {
  df %>%
    arrange(offset) %>%
    transmute(..., day = if_else(offset == 0, "t", sprintf("t%+d", offset)), v = fmt({{ value }})) %>%
    tidyr::pivot_wider(names_from = day, values_from = v)
}

# The pipeline's built tables. They must already be in data/: build them with scripts/make_all.R.
need <- c("calendar", "core_daily", "core_weekly", "core_quarterly", "aux1_distributions", "aux3_debt_h8")
lacking <- need[!file.exists(pipe_path("data", paste0(need, ".rds")))]
if (length(lacking)) stop("not in data/: ", paste0(lacking, ".rds", collapse = ", "),
                          ". Build the tables first: Rscript scripts/make_all.R")
cal   <- readRDS(pipe_path("data", "calendar.rds"))
cored <- readRDS(pipe_path("data", "core_daily.rds"))
core  <- readRDS(pipe_path("data", "core_weekly.rds"))
q     <- readRDS(pipe_path("data", "core_quarterly.rds"))
a1    <- readRDS(pipe_path("data", "aux1_distributions.rds"))
a3    <- readRDS(pipe_path("data", "aux3_debt_h8.rds"))

# Settings
SAMPLE_START <- as.Date("2009-01-01")   # first event: 2009-03-31
SOFR_START   <- as.Date("2018-04-03")   # first SOFR publication
VOL_START    <- as.Date("2016-03-01")   # first FR 2420 day (fed funds volume and percentiles)
OFFSETS      <- -2:2                     # the window: business days around the event
BENCH        <- -12:-3                   # the benchmark: the 10 business days before the window

# The two spreads: series name in core_daily -> label
SPREADS <- c(effr = "EFFR - IOR",
             sofr = "SOFR - IOR")


# =====================================================================================================
# 1. EVENTS AND WINDOWS (calendar)
#    An event is the last business day of a quarter, read from the calendar flags. That handles year
#    ends that are not 31 December (e.g. 2022-12-30) without date arithmetic.
# =====================================================================================================
hr("1. Events: last business day of each quarter, 2009 onward (calendar flags)")

# All business days in order. Offsets count along this vector, so t-1 is the previous BUSINESS day.
bd <- cal$date[cal$is_bday]

events <- cal %>%
  filter(is_bday, is_last_bday_quarter, date >= SAMPLE_START) %>%
  transmute(event_date = date,
            category   = if_else(is_last_bday_year, "year_end", "quarter_end"),
            ep_qe, ep_runoff, ep_rmp, ep_zlb) %>%        # policy episodes, see below
  mutate(idx = match(event_date, bd))

# The policy episodes (QE rounds, balance-sheet runoff, reserve management purchases, zero lower bound)
# are not used in the analysis. They are kept so users can split the events by episode; they travel
# into reserve_supply_by_event.csv and event_panel.csv.

stopifnot(!anyNA(events$idx),                            # every event is a business day
          all(diff(events$event_date) > 80))             # one event per quarter

# window (t-2..t+2) and bench (t-12..t-3): one row per event x offset
around <- function(offsets) {
  events %>%
    select(event_date, category, idx) %>%
    tidyr::crossing(offset = offsets) %>%
    mutate(date = bd[idx + offset]) %>%
    select(-idx)
}
window <- around(OFFSETS)
bench  <- around(BENCH) %>% select(-category)

stopifnot(!anyNA(window$date), !anyNA(bench$date),
          nrow(window) == 5 * nrow(events), nrow(bench) == 10 * nrow(events))

say(nrow(events), " events, ", format(min(events$event_date)), " to ", format(max(events$event_date)), ": ",
    sum(events$category == "year_end"), " year ends, ", sum(events$category == "quarter_end"),
    " other quarter ends. Window t-2..t+2; benchmark = mean over t-12..t-3 (business days).")

# =====================================================================================================
# 2. DAILY SPREADS TO IOR (core_daily)
#    IOR = the pipeline's "ior" composite: IOER until 2021-07-28, IORB after. Every rate is taken as a
#    spread to IOR, so FOMC rate changes (which move both legs) cancel.
# =====================================================================================================
hr("2. Daily spreads to the interest-on-reserves composite (core_daily; bp)")

# One column per rate, one row per business day; starts 60 days early so the first events have a
# full benchmark
wide <- cored %>%
  filter(series %in% c(names(SPREADS), "ior"), date >= SAMPLE_START - 60) %>%
  select(date, series, value) %>%
  tidyr::pivot_wider(names_from = series, values_from = value) %>%
  right_join(tibble(date = bd[bd >= SAMPLE_START - 60]), by = "date") %>%
  arrange(date)

stopifnot(!anyNA(wide$ior), !anyNA(wide$effr))

# A data trap worth knowing, though the ON RRP rate is not used here: core_daily's on_rrp_rate is FRED's
# award rate, blank on business days when the facility drew zero accepted propositions. It is not an
# offering-rate series. A blank can be filled from the previous business day only if IOR (and so the
# offering rate) did not change that day; checked for every blank.
rrp       <- cored %>% filter(series == "on_rrp_rate", !is.na(value))
rrp_days  <- bd[bd >= min(rrp$date) & bd <= max(wide$date)]
gap_days  <- rrp_days[!rrp_days %in% rrp$date]
ior_moved <- wide$date[wide$ior != lag(wide$ior) & !is.na(lag(wide$ior))]
stopifnot(!any(gap_days %in% ior_moved))

say("ON RRP award rate (not used in the analysis): blank on ", length(gap_days), " business days since ",
    format(min(rrp$date)), ", ", sum(gap_days %in% window$date), " of them in event windows; IOR unchanged on all, ",
    "so a previous-day fill would be safe.")

# SOFR: report the SIFMA-closure gaps, leave them NA
sofr_missing <- wide$date[is.na(wide$sofr) & wide$date >= SOFR_START]
say("SOFR: ", length(sofr_missing), " SIFMA closures left NA, in event windows: ",
    paste(format(window$date[window$date %in% sofr_missing]), collapse = ", "), ".")

# Long format: one row per business day x series; spread = rate - IOR (bp)
sp <- wide %>%
  transmute(date,
            effr = effr - ior,
            sofr = sofr - ior) %>%
  tidyr::pivot_longer(all_of(names(SPREADS)), names_to = "series", values_to = "spread") %>%
  arrange(series, date) %>%
  group_by(series) %>%
  mutate(dchg = spread - lag(spread)) %>%
  ungroup()


# =====================================================================================================
# 3. EVENT PANEL: each spread on each window day, against its benchmark
# =====================================================================================================
hr("3. Event panel: each spread against its two-week benchmark (bp)")

# Benchmark = mean spread over t-12..t-3; needs at least 8 of the 10 days, else NA
bench_mean <- bench %>%
  inner_join(sp, by = "date") %>%
  group_by(event_date, series) %>%
  summarise(bench = mean(spread, na.rm = TRUE), n_bench = sum(!is.na(spread)), .groups = "drop") %>%
  mutate(bench = if_else(n_bench >= 8, bench, NA_real_))

# Window days with level, benchmark and deviation. Missing spreads are kept only for SOFR (late start,
# SIFMA closures), so its NAs stay visible in the CSV.
panel <- window %>%
  inner_join(sp, by = "date") %>%
  left_join(bench_mean, by = c("event_date", "series")) %>%
  mutate(dev = spread - bench) %>%
  filter(!is.na(spread) | series == "sofr") %>%
  arrange(series, event_date, offset)

stopifnot(all(table(panel$event_date[panel$series == "effr"]) == 5))   # EFFR on every window day

# Flag events with an FOMC meeting (or its implementation day, date - 1) in t-12..t+2. Spreads to IOR
# largely cancel a rate decision, since both legs move; the flag lets users check that.
fomc_days <- cal$date[!is.na(cal$event) & grepl("fomc_meeting", cal$event)]
fomc_flag <- bind_rows(bench %>% select(event_date, date), window %>% select(event_date, date)) %>%
  group_by(event_date) %>%
  summarise(fomc_in_bench = any(date %in% fomc_days | (date - 1) %in% fomc_days), .groups = "drop")
panel <- panel %>% left_join(fomc_flag, by = "event_date")

say("FOMC meeting inside t-12..t+2 at ", sum(fomc_flag$fomc_in_bench), " of ", nrow(events),
    " events (flagged fomc_in_bench).")

# summ(): by group (...) x series x offset, summarise the deviations across events
summ <- function(df, ...) {
  df %>%
    filter(!is.na(dev)) %>%
    group_by(..., series, offset) %>%
    summarise(n         = n(),
              level_med = median(spread),            # median spread level
              dev_mean  = mean(dev),
              dev_med   = median(dev),
              dev_q25   = quantile(dev, .25),
              dev_q75   = quantile(dev, .75),
              dchg_mean = mean(dchg, na.rm = TRUE),  # mean change from the previous business day
              share_pos = mean(dev > 0),             # share of events above benchmark
              .groups   = "drop")
}

by_cat <- summ(panel, category)                      # by year end / quarter end; Figure 1

say("\nMedian deviation from benchmark by window day (t = period end); n and share above benchmark on day t.")
say("Means, quartiles and day-to-day changes: summary_by_category.csv.")
by_offset(by_cat, dev_med, series, category) %>%
  left_join(by_cat %>% filter(offset == 0) %>% transmute(series, category, n, above = pct(share_pos)),
            by = c("series", "category")) %>%
  arrange(match(series, names(SPREADS)), category) %>%
  show()


# =====================================================================================================
# 4. RESERVE SUPPLY GOING INTO EACH EVENT (core_weekly, core_quarterly + align_quarterly, aux3)
#    Reserves are read on the last H.4.1 Wednesday strictly BEFORE the event, so the measure is known
#    before the period end and not moved by it.
# =====================================================================================================
hr("4. Reserve supply going into each event, with normalisations")

wl <- core_wide(core, "WL")                                         # H.4.1 Wednesday levels
supply_dates <- as.Date(sapply(events$event_date, function(d) max(wl$date[wl$date < d])),
                        origin = "1970-01-01")

# Nominal GDP (quarterly, annual rate) interpolated to those Wednesdays; extend = TRUE lets the latest
# dates use the extended tail (flagged gdp_extended)
gdp <- align_quarterly(q, supply_dates, series = "ngdp", extend = TRUE) %>%
  select(date, ngdp = value, gdp_extended = extended)

# H.8 deposits and total assets of all commercial banks, NSA, Wednesday-dated like H.4.1
h8 <- a3 %>%
  filter(series %in% c("h8_deposits_nsa", "h8_total_assets_nsa")) %>%
  select(date, series, value) %>%
  tidyr::pivot_wider(names_from = series, values_from = value)

# One row per event: reserves, denominators, four ratios, and the reserves/GDP tercile
supply <- events %>%
  mutate(supply_date = supply_dates) %>%
  left_join(wl %>% select(supply_date = date,
                          reserves    = reserve_balances,
                          currency    = currency_in_circulation),
            by = "supply_date") %>%
  left_join(gdp, by = c("supply_date" = "date")) %>%
  left_join(h8,  by = c("supply_date" = "date")) %>%
  mutate(res_gdp    = reserves / ngdp,
         res_dep    = reserves / h8_deposits_nsa,
         res_assets = reserves / h8_total_assets_nsa,
         res_curr   = reserves / currency,
         tercile    = factor(dplyr::ntile(res_gdp, 3), labels = c("low", "mid", "high")))

stopifnot(!anyNA(supply$reserves), !anyNA(supply$ngdp), !anyNA(supply$h8_deposits_nsa),
          all(supply$event_date - supply$supply_date <= 7))

say("Reserves on the last H.4.1 Wednesday before each event; GDP from the extended tail for ",
    paste(format(supply$event_date[supply$gdp_extended]), collapse = ", "),
    ". Per event, with all four ratios: reserve_supply_by_event.csv.")
say("Reserves/GDP terciles: low <= ", fmt(100 * quantile(supply$res_gdp, 1/3)), "%, high > ",
    fmt(100 * quantile(supply$res_gdp, 2/3)), "% of nominal GDP (annual rate).")

# Supply measures into the panel; the event day by tercile
panel <- panel %>%
  left_join(supply %>% select(event_date, res_gdp, res_dep, res_assets, tercile, ep_runoff, ep_qe, ep_rmp),
            by = "event_date")
by_ter <- summ(panel %>% filter(offset == 0), category, tercile)

say("\nMean event-day deviation by reserves/GDP tercile (bp); all statistics: summary_event_day_by_tercile.csv.")
by_ter %>%
  transmute(category, tercile, series, dev_mean = fmt(dev_mean)) %>%
  tidyr::pivot_wider(names_from = series, values_from = dev_mean) %>%
  arrange(category, tercile) %>%
  show()

# Across events: event-day deviation on reserves/GDP (in percentage points)
say("\nSlope of the event-day deviation on reserves/GDP (bp per percentage point of GDP):")
fit <- panel %>%
  filter(offset == 0, !is.na(dev)) %>%
  group_by(series, category) %>%
  group_modify(~ {
    m <- lm(dev ~ I(100 * res_gdp), data = .x)
    tibble(n = nrow(.x), slope = coef(m)[2], se = sqrt(diag(vcov(m)))[2], r2 = summary(m)$r.squared)
  }) %>%
  ungroup()
fit %>% mutate(across(c(slope, se, r2), fmt)) %>% show()


# =====================================================================================================
# 5. THE RATE DISTRIBUTION AROUND THE EVENTS (aux1)
#    (a) Dispersion: does the distribution widen at period ends?
#          range_99_1 = p99 - p1, iqr = p75 - p25 (EFFR from March 2016, SOFR from April 2018)
#          intraday   = brokered high - low of fed funds (EFFR only, before March 2016)
#    (b) Quartiles: which side moves? p25, median (the published rate, a volume-weighted median) and
#        p75, each as a spread to IOR against its own benchmark. Figure 3.
#    Same window / benchmark days as section 3.
# =====================================================================================================
hr("5. Dispersion of the fed funds and SOFR distributions around the events (aux1; bp)")

# (a) One row per date x measure, e.g. measure = "sofr:range_99_1"
dist <- a1 %>%
  filter(series %in% c("dist_effr", "dist_sofr"),
         stat %in% c("p1", "p25", "p75", "p99", "intraday_low", "intraday_high")) %>%
  select(date, series, stat, value) %>%
  tidyr::pivot_wider(names_from = stat, values_from = value) %>%
  transmute(date,
            series     = sub("dist_", "", series),
            range_99_1 = p99 - p1,
            iqr        = p75 - p25,
            intraday   = intraday_high - intraday_low) %>%
  tidyr::pivot_longer(c(range_99_1, iqr, intraday), names_to = "measure", values_to = "value") %>%
  filter(!is.na(value)) %>%
  mutate(measure = paste(series, measure, sep = ":"))

d_bench <- bench %>%                                         # benchmark, at least 8 days
  inner_join(dist, by = "date") %>%
  group_by(event_date, measure) %>%
  summarise(bench = mean(value), n_bench = n(), .groups = "drop") %>%
  filter(n_bench >= 8)

d_panel <- window %>%                                        # window days: difference and ratio
  inner_join(dist, by = "date") %>%
  inner_join(d_bench, by = c("event_date", "measure")) %>%
  mutate(dev = value - bench, ratio = if_else(bench > 0, value / bench, NA_real_)) %>%
  left_join(supply %>% select(event_date, tercile), by = "event_date")

d_sum <- d_panel %>%                                         # across events
  group_by(category, measure, offset) %>%
  summarise(n           = n(),
            level_med   = median(value),
            dev_med     = median(dev),
            ratio_med   = median(ratio, na.rm = TRUE),
            share_wider = mean(dev > 0),
            .groups     = "drop")

say("Dispersion, median widening against benchmark by window day (bp); range_99_1 = p99 - p1, iqr = p75 - p25,")
say("intraday = brokered high - low (EFFR to Feb 2016). Levels, ratios and shares: dispersion_summary.csv.")
by_offset(d_sum, dev_med, measure, category) %>%
  arrange(measure, category) %>%
  show()

# (b) Quartiles as spreads to IOR; the three series start on the same day
pctl <- a1 %>%
  filter(series %in% c("dist_effr", "dist_sofr"), stat %in% c("p25", "rate", "p75"), !is.na(value)) %>%
  transmute(date, series = sub("dist_", "", series), pctl = if_else(stat == "rate", "p50", stat), value) %>%
  group_by(series) %>%
  filter(date >= min(date[pctl == "p25"])) %>%
  ungroup() %>%
  inner_join(wide %>% select(date, ior), by = "date") %>%
  mutate(spread = value - ior)

p_bench <- bench %>%
  inner_join(pctl, by = "date") %>%
  group_by(event_date, series, pctl) %>%
  summarise(bench = mean(spread), n_bench = n(), .groups = "drop") %>%
  filter(n_bench >= 8)

p_panel <- window %>%
  inner_join(pctl, by = "date") %>%
  inner_join(p_bench, by = c("event_date", "series", "pctl")) %>%
  mutate(dev = spread - bench)

p_sum <- p_panel %>%
  group_by(series, category, pctl, offset) %>%
  summarise(n = n(), dev_mean = mean(dev), dev_med = median(dev), .groups = "drop")

say("\nQuartiles (p50 = published rate) as spreads to IOR, median event-day deviation (bp); by day in Figure 3:")
p_sum %>%
  filter(offset == 0) %>%
  transmute(series, category, n, pctl, dev_med = fmt(dev_med)) %>%
  tidyr::pivot_wider(names_from = pctl, values_from = dev_med) %>%
  select(series, category, n, p25, p50, p75) %>%
  arrange(series, category) %>%
  show()


# =====================================================================================================
# 6. VOLUMES AROUND THE EVENTS (aux1)
#    Daily volume behind the published rate: fed funds (FR 2420) and SOFR. From March 2016: before
#    that the only fed funds volume is brokered trades, a narrower universe with a level break.
#    The deviation is in percent of the benchmark mean: SOFR volume has tripled since 2018, and a
#    difference in $bn would mostly track that trend.
# =====================================================================================================
hr("6. Volumes: fed funds (FR 2420) and SOFR, window days vs benchmark (aux1; % of benchmark)")

vol <- a1 %>%                                                # one row per date x series, $bn
  filter(series %in% c("dist_effr", "dist_sofr"), stat == "volume", date >= VOL_START, !is.na(value)) %>%
  transmute(date, series = sub("dist_", "", series), volume = value / 1000)

v_bench <- bench %>%                                         # benchmark, at least 8 days
  inner_join(vol, by = "date") %>%
  group_by(event_date, series) %>%
  summarise(bench = mean(volume), n_bench = n(), .groups = "drop") %>%
  filter(n_bench >= 8)

v_panel <- window %>%                                        # dev_pct = % above benchmark
  inner_join(vol, by = "date") %>%
  inner_join(v_bench, by = c("event_date", "series")) %>%
  mutate(dev_pct = 100 * (volume / bench - 1), dev_bn = volume - bench)

v_sum <- v_panel %>%
  group_by(series, category, offset) %>%
  summarise(n            = n(),
            bench_med_bn = median(bench),
            dev_pct_mean = mean(dev_pct),
            dev_pct_med  = median(dev_pct),
            dev_pct_q25  = quantile(dev_pct, .25),
            dev_pct_q75  = quantile(dev_pct, .75),
            share_higher = mean(dev_pct > 0),
            .groups      = "drop")

say("Median volume against benchmark by window day (%); n, share above benchmark and median benchmark ($bn) on day t.")
say("Means and quartiles: volume_summary.csv.")
by_offset(v_sum, dev_pct_med, series, category) %>%
  left_join(v_sum %>% filter(offset == 0) %>%
              transmute(series, category, n, above = pct(share_higher), bench_bn = round(bench_med_bn)),
            by = c("series", "category")) %>%
  arrange(series, category) %>%
  show()


# =====================================================================================================
# 7. FIGURES (exercise/FIGURES.md documents each one)
#    fig1_ff, fig1_repo   spread by business day around period ends
#    fig2_ff, fig2_repo   event-day spread over time, reserves/GDP below
#    fig3_repo            SOFR 25th percentile, median and 75th percentile around period ends
#    fig4_ff, fig4_repo   event-day volume over time, reserves/GDP below
#    fig5_repo            SOFR rate against volume on the event day
# =====================================================================================================
hr("7. Figures (exercise/figures)")

# --- Style: every look setting in one place -------------------------------------------------------
# Title = the series; subtitle = measure, units, sample range; caption (bottom right) = sources.
FONT        <- if ("Segoe UI" %in% systemfonts::system_fonts()$family) "Segoe UI" else "sans"
BASE_SIZE   <- 12        # pt; other text sizes scale from it
FIG_W       <- 8         # inches; 8 in at 200 dpi = 1600 px
FIG_H       <- 4.8       # single panel (Figures 1, 3)
FIG_H_STACK <- 5.6       # with the reserves panel (Figures 2, 4)
FIG_H_SCAT  <- 5.5       # scatter (Figure 5)

COL_CAT   <- c(quarter_end = "#4C78A8", year_end = "#E45756")
COL_PCTL  <- c(p75 = "#F58518", p50 = "grey15", p25 = "#54A24B")
COL_TITLE <- "black"
COL_TEXT  <- "grey30"    # subtitle, axis text
COL_NOTE  <- "grey45"    # caption
COL_GRID  <- "grey90"
COL_AXIS  <- "grey35"
COL_ZERO  <- "grey40"
COL_BAND  <- "grey50"    # Figure 1 interquartile band
COL_RES   <- c(line = "grey55", point = "grey35", cut = "grey60")    # reserves panel

PT         <- 2.0        # lollipop heads, Figure 3 points
PT_SCAT    <- 2.4        # Figure 5
PT_DOTS    <- 1.6        # Figure 1 event dots
PT_MED     <- 2.6        # Figure 1 median diamonds
PT_RES     <- 1.0        # reserves panel
ALPHA_DOTS <- .5         # Figure 1 event dots
ALPHA_BAND <- .18        # Figure 1 interquartile band
LW         <- .5         # lollipop stems, reserves line
LW_LINE    <- .8         # Figure 3 lines, Figure 1 median line
LW_ZERO    <- .4         # zero lines, grid, axis
LABEL_SIZE <- 2.9        # Figure 5 point labels (mm)

CAT_LAB   <- c(quarter_end = "Quarter ends (not year end)", year_end = "Year ends")
Q_LAB     <- c(p75 = "75th percentile", p50 = "Median (published rate)", p25 = "25th percentile")
SRC_RATES <- "Sources: Federal Reserve Bank of New York, Federal Reserve Board."
SRC_RES   <- "Sources: Federal Reserve Bank of New York, Federal Reserve Board, BEA."

theme_set(
  theme_minimal(base_size = BASE_SIZE, base_family = FONT) +
    theme(plot.title.position   = "plot",
          plot.caption.position = "plot",
          plot.title         = element_text(face = "bold", colour = COL_TITLE, size = rel(1.3), margin = margin(b = 4)),
          plot.subtitle      = element_text(colour = COL_TEXT, margin = margin(b = 8)),
          plot.caption       = element_text(colour = COL_NOTE, size = rel(.72), hjust = 1, margin = margin(t = 8)),
          panel.grid.minor   = element_blank(),
          panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(colour = COL_GRID, linewidth = LW_ZERO),
          axis.line.x        = element_line(colour = COL_AXIS, linewidth = LW_ZERO),
          axis.ticks.x       = element_line(colour = COL_AXIS, linewidth = LW_ZERO),
          axis.ticks.length  = unit(3, "pt"),
          axis.title         = element_text(colour = COL_TEXT, size = rel(.85)),
          axis.text          = element_text(colour = COL_TEXT, size = rel(.85)),
          legend.position    = "top",
          legend.justification = "left",
          legend.margin      = margin(0, 0, 0, 0),
          legend.box.spacing = unit(4, "pt"),
          legend.text        = element_text(size = rel(.85)),
          strip.text         = element_text(face = "bold", colour = COL_TEXT, hjust = 0),
          panel.spacing      = unit(14, "pt"),
          plot.margin        = margin(12, 16, 10, 12)))

# --- Helpers --------------------------------------------------------------------------------------
plus_bp  <- scales::label_number(style_positive = "plus", style_negative = "minus")    # +5, minus sign
plus_pct <- scales::label_number(suffix = "%", style_positive = "plus", style_negative = "minus")

# finish(): append the sample range of the plotted events to the subtitle; sources as the caption.
# Subtitles carry the units, so y axes have no title.
qfull  <- function(d) paste0(format(d, "%Y"), "Q", (as.integer(format(d, "%m")) - 1) %/% 3 + 1)
qrange <- function(d) paste(qfull(min(d)), "to", qfull(max(d)))
finish <- function(p, subtitle, dates, src) {
  p + labs(subtitle = paste0(subtitle, ", ", qrange(dates)), caption = src)
}

# save_fig(): PNG via ragg at 200 dpi. Renders to a temp file and copies it into place with retries:
# on Windows an image viewer can lock the PNG, and ggsave would then leave the old file silently.
RUN_START <- Sys.time() - 1
save_fig <- function(name, plot, height) {
  path <- file.path(fig_dir, name)
  tmp  <- tempfile(fileext = ".png")
  ggsave(tmp, plot, device = ragg::agg_png, dpi = 200, bg = "white", width = FIG_W, height = height)
  for (i in 1:20) {
    if (isTRUE(suppressWarnings(file.copy(tmp, path, overwrite = TRUE)))) break
    Sys.sleep(0.5)
  }
  unlink(tmp)
  if (file.mtime(path) < RUN_START) stop("could not write ", name, " (locked by another program?)")
  name
}

# --- Figure 1: spread by business day around period ends -------------------------------------------
# One dot per event and day (category colour, half transparent), spread sideways within each day in
# date order (oldest left) so events at the same value stay visible. Black = median across events,
# grey band = interquartile range (by_cat). Panels: quarter ends, year ends.
fig_by_day <- function(s, offsets, title, subtitle) {
  ev <- panel %>%
    filter(series == s, offset %in% offsets, !is.na(dev)) %>%
    group_by(category) %>%
    mutate(x = offset + 0.36 * (dense_rank(event_date) / (n_distinct(event_date) + 1) - 0.5)) %>%
    ungroup()
  med <- by_cat %>% filter(series == s, offset %in% offsets)
  p <- ggplot() +
    geom_hline(yintercept = 0, colour = COL_ZERO, linewidth = LW_ZERO) +
    geom_ribbon(data = med, aes(offset, ymin = dev_q25, ymax = dev_q75), fill = COL_BAND, alpha = ALPHA_BAND) +
    geom_point(data = ev, aes(x, dev, colour = category), size = PT_DOTS, alpha = ALPHA_DOTS) +
    geom_line(data = med, aes(offset, dev_med), colour = "black", linewidth = LW_LINE) +
    geom_point(data = med, aes(offset, dev_med), colour = "black", size = PT_MED, shape = 18) +
    facet_wrap(~ category, labeller = as_labeller(CAT_LAB)) +
    scale_colour_manual(values = COL_CAT, guide = "none") +
    scale_x_continuous(breaks = offsets, labels = plus_bp) +
    scale_y_continuous(labels = plus_bp) +
    labs(title = title, x = "Business days from period end", y = NULL)
  finish(p, subtitle, ev$event_date, SRC_RATES)
}

# --- Figures 2 and 4: event-day deviation over time, reserves/GDP below ------------------------------
# Top: one lollipop per event. Bottom: reserves/GDP at each event (supply$res_gdp) with the tercile
# cutoffs dashed, on its own axis. Same date limits, so the events line up vertically.
cuts <- 100 * quantile(supply$res_gdp, c(1/3, 2/3))

fig_event_day <- function(ev, title, subtitle, y_labels = plus_bp) {
  rng     <- range(ev$event_date)
  x_scale <- scale_x_date(limits = rng + c(-60, 60), expand = c(0, 0))
  top <- ggplot(ev, aes(event_date, dev, colour = category)) +
    geom_hline(yintercept = 0, colour = COL_ZERO, linewidth = LW_ZERO) +
    geom_segment(aes(xend = event_date, yend = 0), linewidth = LW) +
    geom_point(size = PT) +
    x_scale +
    scale_y_continuous(labels = y_labels) +
    scale_colour_manual(values = COL_CAT, labels = CAT_LAB) +
    labs(title = title, subtitle = paste0(subtitle, ", ", qrange(ev$event_date)), x = NULL, y = NULL, colour = NULL) +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(), axis.line.x = element_blank())
  bottom <- supply %>%
    filter(event_date >= rng[1], event_date <= rng[2]) %>%
    ggplot(aes(event_date, 100 * res_gdp)) +
    geom_hline(yintercept = cuts, linetype = "dashed", colour = COL_RES[["cut"]], linewidth = LW_ZERO) +
    geom_line(colour = COL_RES[["line"]], linewidth = LW) +
    geom_point(colour = COL_RES[["point"]], size = PT_RES) +
    x_scale +
    scale_y_continuous(breaks = c(5, 10, 15), labels = scales::label_number(accuracy = 1, suffix = "%")) +
    labs(subtitle = "Reserves, % of nominal GDP (dashed lines: tercile cutoffs)", caption = SRC_RES,
         x = NULL, y = NULL) +
    theme(plot.subtitle = element_text(size = rel(.85), colour = COL_TEXT, margin = margin(b = 2)))
  patchwork::wrap_plots(top, bottom, ncol = 1, heights = c(3, 1.2)) &
    theme(plot.margin = margin(6, 16, 6, 12))
}

# --- Figure 3: quartiles of the distribution around period ends -------------------------------------
# Median across events of each percentile's deviation from its benchmark (p_sum), by day.
fig_quartiles <- function(s, title, subtitle) {
  p <- ggplot(p_sum %>% filter(series == s), aes(offset, dev_med, colour = pctl)) +
    geom_hline(yintercept = 0, colour = COL_ZERO, linewidth = LW_ZERO) +
    geom_line(linewidth = LW_LINE) +
    geom_point(size = PT) +
    facet_wrap(~ category, labeller = as_labeller(CAT_LAB)) +
    scale_colour_manual(values = COL_PCTL, labels = Q_LAB, breaks = names(Q_LAB)) +
    scale_x_continuous(breaks = OFFSETS, labels = plus_bp) +
    scale_y_continuous(labels = plus_bp) +
    labs(title = title, x = "Business days from period end", y = NULL, colour = NULL)
  finish(p, subtitle, p_panel$event_date[p_panel$series == s], SRC_RATES)
}

# --- Figure 5: rate against volume on the event day ----------------------------------------------------
# One point per event: x = volume vs benchmark (%, v_panel), y = spread vs benchmark (bp, panel),
# labelled by quarter (18Q4 = 2018-12-31).
fig_rate_volume <- function(s, title, subtitle) {
  d <- panel %>%
    filter(series == s, offset == 0, !is.na(dev)) %>%
    select(event_date, category, dev) %>%
    inner_join(v_panel %>% filter(series == s, offset == 0) %>% select(event_date, dev_pct), by = "event_date") %>%
    mutate(lab = sub("^\\d{2}", "", qfull(event_date)))
  p <- ggplot(d, aes(dev_pct, dev, colour = category)) +
    geom_hline(yintercept = 0, colour = COL_ZERO, linewidth = LW_ZERO) +
    geom_vline(xintercept = 0, colour = COL_ZERO, linewidth = LW_ZERO) +
    geom_point(size = PT_SCAT) +
    ggrepel::geom_text_repel(aes(label = lab), size = LABEL_SIZE, family = FONT, show.legend = FALSE,
                             min.segment.length = 0.3, segment.colour = "grey65", segment.size = .3,
                             box.padding = .3, max.overlaps = Inf, seed = 1) +
    scale_x_continuous(labels = plus_pct) +
    scale_y_continuous(labels = plus_bp) +
    scale_colour_manual(values = COL_CAT, labels = CAT_LAB) +
    labs(title = title, x = "Volume", y = "Rate", colour = NULL) +
    theme(panel.grid.major.x = element_line(colour = COL_GRID, linewidth = LW_ZERO),   # scatter: both grids
          axis.line.x = element_blank(), axis.ticks.x = element_blank())
  finish(p, subtitle, d$event_date, SRC_RATES)
}

# --- Write the figures ---------------------------------------------------------------------------------
event_day <- function(df, s) df %>% filter(series == s, offset == 0)
SUB_BY_DAY <- "Basis points relative to the two-week benchmark, by business day"
SUB_SPREAD <- "Last business day of each quarter, bp relative to the two-week benchmark"
SUB_VOLUME <- "Last business day of each quarter, % relative to the two-week benchmark"

figs <- c(
  save_fig("fig1_ff.png",   fig_by_day("effr", -1:1,    "EFFR minus IOR around period ends", SUB_BY_DAY), FIG_H),
  save_fig("fig1_repo.png", fig_by_day("sofr", OFFSETS, "SOFR minus IOR around period ends", SUB_BY_DAY), FIG_H),
  save_fig("fig2_ff.png",   fig_event_day(event_day(panel, "effr") %>% filter(!is.na(dev)),
                                          "EFFR minus IOR on period-end days", SUB_SPREAD), FIG_H_STACK),
  save_fig("fig2_repo.png", fig_event_day(event_day(panel, "sofr") %>% filter(!is.na(dev)),
                                          "SOFR minus IOR on period-end days", SUB_SPREAD), FIG_H_STACK),
  save_fig("fig4_ff.png",   fig_event_day(event_day(v_panel, "effr") %>% mutate(dev = dev_pct),
                                          "Fed funds volume on period-end days", SUB_VOLUME, plus_pct), FIG_H_STACK),
  save_fig("fig4_repo.png", fig_event_day(event_day(v_panel, "sofr") %>% mutate(dev = dev_pct),
                                          "SOFR volume on period-end days", SUB_VOLUME, plus_pct), FIG_H_STACK),
  save_fig("fig3_repo.png", fig_quartiles("sofr", "SOFR distribution around period ends",
                                          "25th percentile, median and 75th percentile, bp relative to the two-week benchmark"),
           FIG_H),
  save_fig("fig5_repo.png", fig_rate_volume("sofr", "SOFR rate and volume on period-end days",
                                            "SOFR minus IOR (bp) and volume (%), each relative to the two-week benchmark"),
           FIG_H_SCAT))
say("Wrote ", length(figs), " figures and contact_sheet.html.")

# One page with every figure, fed funds and repo side by side (?v= makes the browser reload them)
stamp <- format(Sys.time(), "%Y%m%d%H%M%S")
writeLines(c(
  "<!doctype html><html><head><meta charset='utf-8'><title>Figures</title><style>",
  "body{font-family:'Segoe UI',sans-serif;margin:16px;background:#eee;color:#333}",
  ".grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}@media (max-width:1100px){.grid{grid-template-columns:1fr}}",
  "figure{margin:0;background:#fff;padding:8px;border:1px solid #ccc}",
  "img{width:100%;height:auto;display:block}figcaption{font-size:13px;color:#666;margin-top:4px}",
  "</style></head><body>",
  sprintf("<p>Run %s. Click a figure to open it at full size.</p><div class='grid'>", format(Sys.time(), "%Y-%m-%d %H:%M")),
  sprintf("<figure><a href='%1$s?v=%2$s' target='_blank'><img src='%1$s?v=%2$s'></a><figcaption>%1$s</figcaption></figure>",
          figs, stamp),
  "</div></body></html>"), file.path(fig_dir, "contact_sheet.html"))


# =====================================================================================================
# 8. CSVs AND CHECKS
# =====================================================================================================
hr("8. CSVs (exercise/output) and checks on the results")

write_csv(panel,   file.path(out_dir, "event_panel.csv"))
write_csv(by_cat,  file.path(out_dir, "summary_by_category.csv"))
write_csv(by_ter,  file.path(out_dir, "summary_event_day_by_tercile.csv"))
write_csv(supply,  file.path(out_dir, "reserve_supply_by_event.csv"))
write_csv(d_sum,   file.path(out_dir, "dispersion_summary.csv"))
write_csv(v_panel, file.path(out_dir, "volume_panel.csv"))
write_csv(v_sum,   file.path(out_dir, "volume_summary.csv"))
if (anyNA(by_cat$dev_q25)) say("note: IQR band undefined for ", sum(is.na(by_cat$dev_q25)), " summary rows")

# Every figure was written by this run; stop if a rebuild changes the basic picture
stopifnot(all(file.size(file.path(fig_dir, figs)) > 20000))
ye_effr <- by_cat %>% filter(series == "effr", category == "year_end",    offset == 0)
qe_effr <- by_cat %>% filter(series == "effr", category == "quarter_end", offset == 0)
stopifnot(ye_effr$n >= 15, qe_effr$n >= 45)

say("Wrote 7 CSVs. Checks passed: EFFR sample sizes (", ye_effr$n, " year ends, ", qe_effr$n, " quarter ends).")
