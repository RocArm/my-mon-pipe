# example_usage.R -- worked examples against the built tables. Runs end to end:
#   Rscript scripts/example_usage.R
# Each block is independent; copy what you need.
args <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", args[grepl("^--file=", args)])
root <- if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
options(mmp.root = root)
for (s in sort(list.files(file.path(root, "R"), full.names = TRUE))) source(s)

cal   <- readRDS(pipe_path("data", "calendar.rds"))
cored <- readRDS(pipe_path("data", "core_daily.rds"))
core  <- readRDS(pipe_path("data", "core_weekly.rds"))
q     <- readRDS(pipe_path("data", "core_quarterly.rds"))

# 1. Weekly wide tables: one column per series ------------------------------------------------------
wl <- core_wide(core, "WL")                          # Wednesday levels
wa <- core_wide(core, "WA", grid = weekly_grid(cal))   # week averages on the full grid (NA where absent)
cat("wl:", nrow(wl), "weeks x", ncol(wl) - 1, "series\n")

# 2. Reserves / nominal GDP, weekly ------------------------------------------------------------------
# align_quarterly() interpolates GDP linearly between mid-quarter anchors. The latest weeks are NA until a
# GDP anchor exists; extend = TRUE fills them at potential-GDP growth and flags them.
gdp <- align_quarterly(q, wl$date, extend = TRUE) %>% filter(series == "ngdp") %>% select(date, ngdp = value, extended)
r <- wl %>% select(date, reserve_balances) %>% inner_join(gdp, by = "date") %>% mutate(ratio = reserve_balances / ngdp)
print(tail(r, 3))

# 3. Daily spread with period-end flags -----------------------------------------------------------------
d <- cored %>% filter(series %in% c("effr", "ior")) %>% select(date, series, value) %>%
  pivot_wider(names_from = series, values_from = value) %>%
  mutate(spread_bp = effr - ior) %>%
  left_join(cal %>% select(date, is_last_bday_month, is_last_bday_quarter), by = "date")
print(d %>% filter(is_last_bday_quarter) %>% tail(4))

# 4. Which weeks contain a quarter end (to read core_weekly around period ends) -----------------------
qe <- cal %>% distinct(week_wed, week_has_quarter_end) %>% rename(date = week_wed)
print(core %>% filter(series == "on_rrp_overnight_tsy", stat == "WL") %>% inner_join(qe, by = "date") %>%
        filter(week_has_quarter_end) %>% tail(3))

# 5. Indicative history, explicitly and with the warning ---------------------------------------------
leg <- readRDS(pipe_path("data", "legacy_indicative.rds"))
a1  <- readRDS(pipe_path("data", "aux1_distributions.rds"))
long_sofr <- splice_indicative(a1 %>% filter(stat == "rate"), leg, "dist_sofr", "ind_sofr")
print(table(sub(":.*", "", long_sofr$source)))
