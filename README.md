# my-mon-pipe

Unified data pipeline for money-market and Federal Reserve balance-sheet work. One shared calendar, one
weekly core table, five auxiliary pipes, one legacy pipe. R, no API keys.

Documentation map:

- this README: conventions, outputs, setup, running, using, extending, caveats
- `docs/DECISIONS.md`: every design decision, its reason and its downstream effect (D1 to D22)
- `docs/SOURCES.md`: endpoints, verification dates, source quirks; `docs/inventory/` holds the evidence
- `docs/DATA_DICTIONARY.md`: every series, generated from the registry
- `config/h41_split.md`: which H.4.1 lines are core and which are auxiliary

## Conventions (non-negotiable)

- **Dollars in millions of USD** (`usd_mn`). **Rates in basis points** (`bp`). Conversions happen once, at
  load, with the multiplier in `config/series_registry.csv`. No loader contains a divisor.
- **Business days only** for every daily series: inner join to `data/calendar` (NY Fed EFFR publication
  dates from 2000-07-03, minus `config/calendar_exclusions.csv`). Month, quarter and year ends are the last
  business day on or before the calendar end.
- **Core has a daily table and a weekly table, both from 2002-12-18.** `core_daily` holds the rates and
  operation amounts on business days. `core_weekly` sits on the H.4.1 grid (nominal Wednesdays) and carries
  every daily series twice, as `WL` (value on the Wednesday-level date) and `WA` (mean over the seven
  calendar days Thu..Wed with non-business days carrying the last business-day value, the H.4.1 and H.15
  construct), beside the H.4.1 lines.
- **Latest vintage only.**
- **No silent splice of indicative history.** The legacy pipe warns on load; `splice_indicative()` is the only
  join and flags every row.

## Outputs (`data/`, not committed)

| Output | Pipe | Content |
|---|---|---|
| `calendar` | - | daily, 2000-07-03 →: `is_bday`, `week_wed` (H.4.1 week id), `wl_date`, first/last business day of month/quarter/year, `week_has_*_end`, `event` |
| `core_daily` | core | business days from 2002-12-18: EFFR, OBFR, SOFR; targets; IOER/IORR/IORB; ON RRP rate; primary credit rate; overnight ON RRP and repo amounts; composites `target_top`, `target_bottom`, `ior` (native daily values, `stat` empty) |
| `core_weekly` | core | 17 H.4.1 lines (WA+WL) + total assets; every `core_daily` series reduced to WL and WA |
| `core_quarterly` | core | nominal GDP and CBO nominal potential GDP as published. Align with `align_quarterly()` |
| `aux1_distributions` | 1 | NY Fed API: EFFR, OBFR, SOFR, BGCR, TGCR daily: rate, percentiles, volume, target range, intraday range, std dev, revision flag |
| `aux2_h41_rest` | 2 | every other H.4.1 Table 1/1A/5 line, weekly |
| `aux3_debt_h8` | 3 | FRED debt aggregates (quarterly), MSPD table 1 via FiscalData (monthly, `mspd_*`), H.8 weekly and monthly |
| `aux4_treasury_rates` | 4 | DGS1/2/5/10, DFII10, DTB4WK/3/6 daily; TB3MS, GS10 monthly |
| `aux5_operations`, `aux5_rrp_by_counterparty` | 5 | NY Fed API operation-level repo/RRP results and ON RRP by counterparty type (wide) |
| `legacy_indicative` | legacy | `ind_tgcr`, `ind_bgcr`, `ind_sofr`, `ind_effr_brokered`, `ind_sofr_averages` |

All long tables share the schema `date, series, stat, value, unit, source`. Each is saved as `.rds` and `.csv`.
`data/raw/` keeps every download as received, one file per source id per build date. `data/build_log.txt`
lists each series with first/last date, count, unit and any warning.

### Vocabulary

| Column | Values | Meaning |
|---|---|---|
| `stat` (core_daily) | empty | native daily value on a business day |
| `stat` (H.4.1 rows) | `WA`, `WL` | week average (7 calendar days, as published) / Wednesday level |
| `stat` (daily series in core_weekly) | `WA`, `WL` | 7-calendar-day carry-forward mean Thu..Wed / value on `wl_date` |
| `stat` (aux1) | `rate`, `p1`, `p25`, `p75`, `p99`, `volume`, `target_from`, `target_to`, `intraday_low`, `intraday_high`, `std_dev`, `revised` | published rate and distribution; `revised` is 0/1 |
| `stat` (aux3 `mspd_*`) | `public`, `intragov`, `total` | debt held by the public, intragovernmental holdings, total outstanding |
| `stat` (legacy) | `rate`, `volume`, `p1`..`p99`, `avg30`, `avg90`, `avg180`, `index` | as in the NY Fed files |
| `unit` | `usd_mn`, `bp`, `flag`, `ratio` | millions of dollars; basis points; 0/1; dimensionless index |
| `source` | FRED id; `nyfed:<path>`; `fiscaldata:<table>`; `nyfed_static:<file>` | where the value came from. Composites carry the raw id(s) used, e.g. `DFEDTAR+DFEDTARU` in a transition week. After `splice_indicative()`: `indicative:<...>` or `official:<...>` |
| calendar `week_wed` | a Wednesday | id of the Thu..Wed week the date belongs to |
| calendar `wl_date` | a business day | last business day on or before `week_wed`; the date a daily series is read for `WL` |
| calendar `week_has_month_end` etc. | logical | the week contains the last business day of a month / quarter / year |

In `aux5`, column names carry the unit: `($Billions)` became `(usd_mn)`, `(%)` rates became `(bp)`, and
`Amt At Stop-Out` is an allotment share kept as `(pct_share)`.

## Setup

- R 4.5 with `tidyverse`, `httr`, `readxl`, `jsonlite`, `lubridate` (all CRAN). Nothing else; no API keys.
- Python 3 is needed only to regenerate the registry and data dictionary (`scripts/build_registry.py`,
  standard library only).
- Network access to fred.stlouisfed.org, markets.newyorkfed.org, api.fiscaldata.treasury.gov.

## Run

```
Rscript scripts/make_core.R        # calendar + core only (~15 s)
Rscript scripts/make_all.R         # everything, then tests (~2 min, mostly ~160 FRED downloads)
Rscript tests/run_tests.R          # tests only; add --units to re-check FRED unit strings (slow)
```

Every run downloads everything again (there is no incremental update) and overwrites `data/`. The raw cache
is append-only by date, so previous downloads remain under `data/raw/` for comparison.

## Quick start

```r
options(mmp.root = "C:/Work/WorkGit/my-mon-pipe")
for (s in sort(list.files(file.path(getOption("mmp.root"), "R"), full.names = TRUE))) source(s)
core  <- readRDS(pipe_path("data", "core_weekly.rds"))   # long: date, series, stat, value, unit, source
wl    <- core_wide(core, "WL")                            # one column per series, Wednesday levels
```

Worked examples (GDP ratios, daily spreads with period-end flags, quarter-end weeks, the indicative splice)
are in `scripts/example_usage.R`, which runs end to end against the built tables. Helper functions, all in
`R/`: `core_wide()`, `weekly_grid()`, `bdays_of()`, `to_bdays()`, `daily_to_weekly()`, `align_quarterly()`,
`splice_indicative()`.

## Extend

To add, drop or re-scope a series: edit `scripts/build_registry.py` (one `add()` or `h41()` call), run
`python scripts/build_registry.py`, then `Rscript scripts/make_all.R`. The registry row drives download, unit
conversion and placement; the tests check that every row produced output and that units land in bands.
Registry columns are documented at the top of the generator.

To exclude a date FRED carries but the NY Fed never published, add it to `config/calendar_exclusions.csv`
with the reason.

## Caveats a user must know

- **WA of a daily series is the H.4.1 construct.** Seven calendar days Thu..Wed, each non-business day carrying the
  last business-day value (two carried days in a normal week). WA and WL of a step series differ only in weeks
  with an intra-week change (D8).
- **Interpolated GDP is derived and revises.** Weekly GDP from `align_quarterly()` is linear between mid-quarter
  anchors. **The latest two to three months are NA by default** because no GDP anchor exists yet; pass
  `extend = TRUE` to fill them at potential-GDP growth, flagged `extended = TRUE` (D11, D12).
- **Operation amounts are zero-filled** on business days without an operation, from each series' first
  observation (D14).
- **Core has daily rates and operation amounts (`core_daily`) but no daily H.4.1 quantities.** Balance-sheet
  stocks exist weekly only; daily rate distributions and operation detail live in aux1 and aux5 (D2).
- **Nothing before 2000-07-03; core from 2002-12-18; primary credit rate from 2003-01-09** (D10).
- **FRED's SOFR starts one day after the NY Fed's** (2018-04-03 vs 2018-04-02).
- **ON RRP by counterparty type lags about a quarter**; recent rows have the total only.
- **The `--units` test is the guard against FRED unit changes**; run it after any unexplained level shift (D5).
- Line endings: files are LF (`.gitattributes`); Windows Git may show CRLF warnings, which are harmless.

## Status

Initial build 2026-11-08; `core_daily` added, WA switched to the 7-day construct and H.3 dropped 2026-11-09. All pipes built, 65 tests passing. Events dataset (FOMC dates, policy changes,
balance-sheet announcements, recessions) is a TODO on hold; `config/events.csv` holds four seed dates.
