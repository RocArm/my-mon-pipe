# Figures: period ends in the fed funds and repo markets

`exercise/year_quarter_ends.R` uses the pipeline's built tables to study how money-market rates and
volumes behave around quarter ends and year ends, 2009 onward. It writes eight figures to
`exercise/figures/`, together with a printed log and seven CSVs in `exercise/output/`:

```
Rscript scripts/make_all.R             # build the pipeline tables in data/ (once)
Rscript exercise/year_quarter_ends.R   # about 20 seconds
```

`exercise/figures/contact_sheet.html` shows all eight figures on one page. Figures come in a fed
funds version (`_ff`, EFFR) and a repo version (`_repo`, SOFR); Figures 3 and 5 are repo only.

| File | Content | Pipeline tables |
|---|---|---|
| `fig1_ff`, `fig1_repo` | Spread to IOR by business day around period ends | calendar, core_daily |
| `fig2_ff`, `fig2_repo` | Event-day spread over time, with reserves/GDP | calendar, core_daily, core_weekly, core_quarterly |
| `fig3_repo` | SOFR 25th percentile, median and 75th percentile around period ends | calendar, core_daily, aux1 |
| `fig4_ff`, `fig4_repo` | Event-day volume over time, with reserves/GDP | calendar, aux1, core_weekly, core_quarterly |
| `fig5_repo` | SOFR rate against volume on the event day | calendar, core_daily, aux1 |

The figures carry only a title, a subtitle (measure, units, sample range) and the sources. Everything
else needed to read them is below.

---

## How the pipeline tables are used

| Table | What the script takes from it |
|---|---|
| `calendar.rds` | Business days (`is_bday`), last business day of the quarter and year (`is_last_bday_quarter`, `is_last_bday_year`), FOMC meetings (`event`), policy episodes (`ep_*`) |
| `core_daily.rds` | EFFR, SOFR and the IOR composite (`ior`); the ON RRP award rate only for a data-trap note in the log |
| `core_weekly.rds` | H.4.1 reserve balances and currency at Wednesday level, via `core_wide(core, "WL")` |
| `core_quarterly.rds` | Nominal GDP, interpolated to the H.4.1 Wednesdays with `align_quarterly(..., extend = TRUE)` |
| `aux1_distributions.rds` | NY Fed percentiles (`p1`, `p25`, `p75`, `p99`), published rate (`rate`) and `volume` for EFFR and SOFR |
| `aux3_debt_h8.rds` | H.8 deposits and total assets of commercial banks (used in the log and CSVs, not in the figures) |

## Definitions common to all figures

**Period end (event).** The last business day of each calendar quarter, taken from the calendar
flags, not computed from dates. 71 events from 2009Q1 (2009-03-31) to 2026Q3 (2026-09-30): 17 year
ends and 54 other quarter ends. Five year ends fall before 31 December: 2011-12-30, 2016-12-30,
2017-12-29, 2022-12-30 and 2023-12-29. Figure 5 labels events by quarter, for example 18Q4 for
2018-12-31.

**Quarter ends versus year ends.** Quarter ends exclude year ends. Blue = quarter end, red = year
end, in every figure.

**Business days around the event.** Offsets count business days on the fed funds calendar, so t−1 is
the previous business day, skipping weekends and holidays. The window is t−2 to t+2.

**Two-week benchmark.** The mean of the same series over business days t−12 to t−3, i.e. the ten
business days before the window. A benchmark needs at least 8 of the 10 days; otherwise the event is
dropped for that series.

**Rate measures.** Each rate is a spread to interest on reserves (IOR): IOER until 2021-07-28, IORB
from 2021-07-29. Using the spread means FOMC rate changes, which move both legs, cancel out. The
figures show the spread on a day minus its benchmark, in basis points.

**Volume measures.** Volume on a day relative to its benchmark mean, in percent:
100 × (volume / benchmark − 1). Percent rather than $bn because SOFR volume roughly tripled over
the sample.

**Reserves, % of nominal GDP** (bottom panel of Figures 2 and 4). Reserve balances with Federal
Reserve Banks, Wednesday level (H.4.1, FRED `WRBWFRBL`), on the last H.4.1 Wednesday before each
event, divided by nominal GDP (BEA, SAAR, FRED `GDP`) interpolated to that week. For the latest
events GDP is extended past the last release. The dashed lines are the tercile cutoffs of this
ratio across the 71 events: 9.6% and 11.9%.

## Caveats that apply to several figures

- **2020Q1 (2020-03-31).** The benchmark window, 13 to 26 March 2020, spans the emergency rate cut
  of 15 March. The EFFR and SOFR deviations for this event (about −9 bp and −10 bp on the day) say
  more about the benchmark than about the period end.
- **2019Q3 (2019-09-30), SOFR.** The benchmark window includes the 16–17 September 2019 repo spike,
  which pushes the benchmark up by about 48 bp. SOFR deviations for this event are therefore around
  −40 bp on every window day (visible in `fig1_repo`).
- **2018Q4 (2018-12-31), SOFR.** The largest observation: +56 bp on the day and +71 bp at t+1. It
  sets the y scale of the SOFR figures.
- **Good Friday, SOFR.** SOFR is not published on SIFMA closures. 2024-03-29 is a period end
  (2024Q1), so that event has no SOFR rate or volume on the event day. 2021-04-02 is t+2 of
  2021Q1. Both are left missing; nothing is filled in.
- **Fed funds volume and percentiles start in March 2016.** They come from the FR 2420 report.
  Before that, the only fed funds volume is brokered trades, a narrower universe with a level break
  at 2016-03-01, so it is not used.

## Sources

| Series | Publisher | Retrieved via |
|---|---|---|
| EFFR, SOFR (rates) | Federal Reserve Bank of New York | FRED (`EFFR`, `SOFR`) |
| IOER, IORB | Federal Reserve Board | FRED (`IOER`, `IORB`) |
| Volumes and percentiles of EFFR (FR 2420) and SOFR | Federal Reserve Bank of New York | NY Fed Markets data (`rates/.../search.csv`) |
| Reserve balances, Wednesday level | Federal Reserve Board, H.4.1 | FRED (`WRBWFRBL`) |
| Nominal GDP | BEA | FRED (`GDP`) |

---

## Figure 1: spread around period ends, by business day

**Files:** `fig1_ff.png` (EFFR), `fig1_repo.png` (SOFR). **Function:** `fig_by_day()`.

**What it shows.** For each business day around the period end, the spread to IOR minus its
two-week benchmark (bp), for every event. Left panel quarter ends, right panel year ends, same y axis.

- **Dots:** one per event and day, in the category colour at 50% opacity. Within each day the dots
  are spread sideways in date order, oldest on the left, so the many events at exactly 0 stay
  visible. The horizontal position within a day carries no other meaning.
- **Black line and diamonds:** the median across events for each day.
- **Grey band:** the interquartile range across events for each day.

**Sample.** EFFR: 71 events, 2009Q1 to 2026Q3, days t−1 to t+1 shown (the tables keep t−2 to t+2).
SOFR: 34 events, 2018Q2 to 2026Q3, days t−2 to t+2.

**Notes.** In `fig1_repo` the dots near −40 bp are 2019Q3 (benchmark caveat above); the year-end dots
at +56 and +71 bp are 2018Q4.

## Figure 2: spread on the period-end day, over time

**Files:** `fig2_ff.png` (EFFR), `fig2_repo.png` (SOFR). **Function:** `fig_event_day()`.

**What it shows.** Top: the spread to IOR on the event day (t) minus its two-week benchmark (bp),
one lollipop per event, coloured by category. Bottom: reserves, % of nominal GDP, at each event,
with the tercile cutoffs dashed. The two panels share the time axis, so each event lines up with
its reserve level.

**Sample.** EFFR: 71 events, 2009Q1 to 2026Q3. SOFR: 33 events, 2018Q2 to 2026Q3 (2024Q1 missing,
Good Friday).

## Figure 3: SOFR distribution around period ends

**File:** `fig3_repo.png`. **Function:** `fig_quartiles()`.

**What it shows.** Three points of the SOFR transaction distribution: 25th percentile, median and
75th percentile. The median is the published SOFR, a volume-weighted median. Each percentile is
taken as a spread to IOR and compared with its own two-week benchmark. Lines show the median of
that deviation across events, by business day t−2 to t+2. Left panel quarter ends, right panel year
ends.

**Sample.** 2018Q2 to 2026Q3: 25 quarter ends and 8 year ends on the event day.

**Notes.** The lines are medians of per-event deviations, so the gap between the 75th and 25th
percentile lines is not the median change in the interquartile range. The 1st and 99th percentiles
are in the log and `dispersion_summary.csv` but not plotted: too noisy.

## Figure 4: volume on the period-end day, over time

**Files:** `fig4_ff.png` (fed funds), `fig4_repo.png` (SOFR). **Function:** `fig_event_day()`, same
layout as Figure 2.

**What it shows.** Top: volume on the event day relative to its two-week benchmark (%), one lollipop
per event. Bottom: reserves, % of nominal GDP, as in Figure 2.

**Sample.** Fed funds: 43 events, 2016Q1 to 2026Q3 (FR 2420 volume, March 2016 on). SOFR: 33 events,
2018Q2 to 2026Q3 (2024Q1 missing, Good Friday).

## Figure 5: SOFR rate against volume on the period-end day

**File:** `fig5_repo.png`. **Function:** `fig_rate_volume()`.

**What it shows.** One point per event, on the event day. x: SOFR volume relative to its two-week
benchmark (%). y: SOFR minus IOR relative to its two-week benchmark (bp). Coloured by category,
labelled by quarter (18Q4 = 2018-12-31).

**Sample.** 33 events, 2018Q2 to 2026Q3 (2024Q1 missing, Good Friday).

**Notes.** 2020Q1 (bottom left) is affected by the benchmark caveat above.

---

## Style

All look settings (font, text size, colours, point sizes, line widths, figure sizes) are in one
block at the start of section 7 of the script. Figures are 8 in wide at 200 dpi (1600 px), rendered
with `ragg`, in Segoe UI where available (otherwise the default sans-serif font).
