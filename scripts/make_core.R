# make_core.R -- build calendar + core (weekly and quarterly). Run from anywhere:
#   Rscript scripts/make_core.R            (repo root inferred from this file's location)
args <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", args[grepl("^--file=", args)])
root <- if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
options(mmp.root = root)
for (s in sort(list.files(file.path(root, "R"), full.names = TRUE))) source(s)

t0 <- Sys.time()
log_line("==== make_core start (root ", root, ")")
reg <- read_registry()

effr <- fred_csv("EFFR")
cal  <- build_calendar(effr)
save_table(cal, "calendar")
log_line("calendar ", format(min(cal$date)), " -> ", format(max(cal$date)),
         "  bdays=", sum(cal$is_bday), "  weeks=", n_distinct(cal$week_wed))

core <- build_core(reg, cal)
save_table(core$weekly, "core_weekly")
save_table(core$daily,  "core_daily")

coreq <- build_core_quarterly(reg)
save_table(coreq, "core_quarterly")

log_line("==== make_core done in ", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s")
