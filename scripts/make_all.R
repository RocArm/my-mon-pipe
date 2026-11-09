# make_all.R -- build every pipe, then run the tests.   Rscript scripts/make_all.R
args <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", args[grepl("^--file=", args)])
root <- if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
options(mmp.root = root)
for (s in sort(list.files(file.path(root, "R"), full.names = TRUE))) source(s)

t0 <- Sys.time()
log_line("==== make_all start (root ", root, ")")
reg <- read_registry()

cal <- build_calendar(fred_csv("EFFR"));          save_table(cal, "calendar")
log_line("calendar ", format(min(cal$date)), " -> ", format(max(cal$date)), "  bdays=", sum(cal$is_bday))

core <- build_core(reg, cal)
save_table(core$weekly,                     "core_weekly")
save_table(core$daily,                      "core_daily")
save_table(build_core_quarterly(reg),       "core_quarterly")
save_table(build_aux_fred(reg, cal, "aux2"), "aux2_h41_rest")
save_table(build_aux3(reg, cal),            "aux3_debt_h8")
save_table(build_aux_fred(reg, cal, "aux4"), "aux4_treasury_rates")
save_table(build_aux1(reg, cal),            "aux1_distributions")
ops <- build_aux5(reg, cal)
save_table(ops$results,                     "aux5_operations")
save_table(ops$rrp_by_counterparty,         "aux5_rrp_by_counterparty")
save_table(build_legacy(cal),               "legacy_indicative")

log_line("==== make_all done in ", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s; running tests")
status <- system2("Rscript", c(file.path(root, "tests", "run_tests.R")), stdout = "", stderr = "")
if (!identical(as.integer(status), 0L)) {
  log_line("==== TESTS FAILED (exit ", status, "). data/ already holds the new tables: inspect before using them.")
  quit(status = 1)
}
log_line("==== tests passed")
