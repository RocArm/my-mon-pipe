# Design decisions

Decisions taken while building the pipeline (October to November 2026), with the reason and, where it
matters, the **downstream effect** a user must keep in mind. Numbered for reference; D-numbers are stable.

## Scope and architecture

**D1. Two layers: a core pipe and separate auxiliary pipes.**
Core holds what every analysis loads; each auxiliary pipe holds what some analyses need. Pipes are built by
separate functions and saved as separate tables.
*Effect:* a project loads core plus the pipes it needs; nothing forces loading everything. A series lives in
exactly one pipe, so a ratio across pipes (e.g. reserves to H.8 deposits) is a join on `date`, not a lookup.

**D2. Core is FRED-only and has two tables: `core_daily` and `core_weekly`, both from 2002-12-18.**
`core_daily` holds the rates and overnight operation amounts on business days. `core_weekly` sits on the
H.4.1 grid (nominal Wednesdays from 2002-12-18, the first H.4.1 observation FRED serves) and carries the
H.4.1 lines plus every daily series reduced to WL and WA. All core series come from FRED's keyless CSV
endpoint; no API keys anywhere. (Revised 2026-11-09: the first build had the weekly table only; the daily
values of targets, administered rates and operation amounts were then available in no output.)
*Effect:* daily rate and operation dynamics are in `core_daily`; daily H.4.1 quantities do not exist. Every
`core_daily` series also appears in `core_weekly` as WA and WL (D8), so the weekly table is self-contained.
BGCR and TGCR are excluded from core because FRED does not carry them (D4). The 2000-07 to 2002-12 daily
rate history is absent from core (grid start) but present in aux1 for the five reference rates.

**D3. Core content.**
Reference rates EFFR, OBFR, SOFR; FOMC targets; administered rates IOER, IORR, IORB, ON RRP award rate,
primary credit rate; the overnight ON RRP and repo amounts; 16 H.4.1 lines (WA+WL) plus total assets (WL) (see
`config/h41_split.md`); nominal GDP and CBO nominal potential GDP.
*Effect:* real GDP, inflation, unemployment, SEP, NBER dummies, SOFR averages and SOMA CUSIP detail are not in
the pipeline at all (D15 to D17). Discount-window quantities are in aux2, only the rate is in core.
IOER, IORR and IORB are kept as three separate raw series; the only join is the `ior` composite of D9
(IOER then IORB, IORR excluded), which carries a `source` column.

**D4. BGCR and TGCR dropped from core; kept in aux1.**
Not on FRED; SOFR is the broadest secured rate and the one every inherited project used.

## Units and calendar

**D5. Dollars in millions, rates in basis points, converted once at load from the registry multiplier.**
No loader contains a divisor; `config/series_registry.csv` holds `source_unit`, `target_unit`, `multiplier`.
*Effect:* a FRED unit change (as happened to WRESBAL/WCURCIR/WTREGEN/WSECOUT in 2025, when FRED switched them
from billions with pre-2002 history to millions from 2002) would silently corrupt the build; the optional
`--units` test re-reads each FRED series page to catch it. Run it after any surprising level shift.

**D6. Business days only, from one shared calendar.**
Calendar = FRED's non-blank EFFR dates from 2000-07-03, minus `config/calendar_exclusions.csv` (FRED-only
dates the NY Fed never published; 2002-02-18) plus `config/calendar_inclusions.csv` (NY Fed publication days
on which FRED's EFFR is blank; six days, added 2026-11-09 after a cold review found them: 2001-03-27,
2003-10-10, 2003-10-30, 2003-10-31, 2006-11-06, 2006-11-14). The result equals the NY Fed EFFR publication
days; both directions are tested against the raw API file. FRED stays the anchor (user's choice 2026-11-09)
so core remains FRED-only; the two config files are the complete reconciliation.
Every daily series is inner-joined to it. Period ends are the last business day on or before the calendar end;
the flags are suppressed for the running month, quarter and year.
*Effect:* weekday holidays carried by FRED (e.g. the primary credit rate on 2024-12-25) are dropped. Good
Friday is a business day (the Fed publishes EFFR), but SOFR, Treasury yields and the ON RRP award rate can be
absent on calendar business days (SIFMA closures; zero-take-up days): the daily tables then have no row and
the WA carries the previous value. The calendar has no forward extension and nothing before 2000.

**D7. H.4.1 week = Thursday to Wednesday; Wednesday-level date = last business day on or before the Wednesday.**
*Effect:* when Wednesday is a holiday (16 cases since 2000-07-03, 15 on the core grid), the WL of a daily series is Tuesday's value, dated on the
nominal Wednesday. The running, incomplete week is never written.

**D8. Daily series enter `core_weekly` twice: WL and WA; the WA is the 7-calendar-day carry-forward mean.**
The native daily values are in `core_daily`; the weekly WL equals the daily value on the calendar's
Wednesday-level date (tested). The WA averages the seven calendar days Thu..Wed, each non-business day
carrying the last business-day value: a week has five business days, so on average two days are carried,
and an overnight amount dealt on Friday counts Friday, Saturday and Sunday. This is the construct of the
H.4.1 week averages and of the H.15 weekly rate averages. (Revised 2026-11-09 from a business-day mean:
on weeks with no term operations the 7-day WA of the FRED overnight ON RRP amount reproduces the H.4.1
ON RRP week average exactly in 641 of 665 weeks, the business-day mean in 17.)
*Effect:* WA and WL of a step series (targets, IOR, primary credit rate, ON RRP rate) differ only in weeks
containing an intra-week change: before December 2008 target changes took effect on the meeting day
(Wednesday) so WA ≠ WL in every change week; since then they take effect the next day (Thursday, the start
of the H.4.1 week) so WA = WL except for intermeeting moves and the shifted November 2024 meeting. The
inequality "H.4.1 ON RRP stock ≥ overnight amount" holds for both WL and WA and is tested for both.
The carry-forward is bounded by each series' last observation (fixed 2026-11-09: the first version carried
DFEDTAR, IOER and IORR to the present as WA, 1,484 fabricated rows); a WA never postdates the series' last WL
(tested), and discontinued series must end by the registry's `end_expected` (tested).

## Policy-rate history

**D9. Raw policy series kept; three composites added with a `source` column.**
`target_top` / `target_bottom` = single target before 2008-12-16 (zero-width range), range after; `ior` = IOER
to 2021-07-28, IORB after. IORR kept raw only. No composite for the ON RRP rate or SOFR.
*Effect:* in the week containing a regime change the WA mixes regimes and `source` reads e.g.
`DFEDTAR+DFEDTARU`. Spreads to "the target" before 2008 are spreads to the single target.
These are official-series joins and carry no indicative warning.

**D10. Nothing before 2000-07-03 anywhere; core from 2002-12-18.**
The user's horizon starts with the modern fed funds data; DFF (1954→), the 1982–2000 single target and the
pre-2003 adjustment-credit discount rate are not pulled. The primary credit rate starts 2003-01-09 (a
Thursday), so its first four core weeks (2002-12-18 to 2003-01-08) are empty and its first WL/WA week is 2003-01-15.

## GDP alignment

**D11. GDP stored quarterly as published; aligned on demand; default = linear interpolation between mid-quarter anchors.**
Anchor = quarter start + 45 days. Step alignment is available (`method = "step"`): the published value of the
quarter containing the date, NA after the last day of the last published quarter (fixed 2026-11-09; it used to
carry the last quarter forward with `extended = FALSE`). Linear was chosen over step because a step
denominator makes weekly ratios saw-tooth at quarter boundaries.
*Effect:* interpolated weekly GDP is **derived**, carries `method = "linear"`, and changes when the next quarter
is released. Old projects interpolated between FRED's quarter-start dates, which is about six weeks early;
results will differ from theirs by that shift.

**D12. Tail of actual GDP: NA by default; optionally extended at the growth rate of potential GDP, flagged `extended = TRUE`.**
`align_quarterly(..., extend = FALSE)` is the default (decided 2026-11-09): a casual call never returns
provisional numbers. `extend = TRUE` fills the weeks after the last mid-quarter anchor at potential-GDP
growth and flags them.
*Effect:* with the default, every GDP ratio is blank for the latest ~8–16 weeks until the next GDP release.
With `extend = TRUE` those weeks are provisional and will be revised. Potential GDP never needs extension
(projections to 2036).

**D13. Latest vintage only.**
*Effect:* no real-time analysis; every rebuild overwrites history with current revisions. Real-time work would
be an ALFRED module, not built.

## Operations

**D14. Core carries the FRED daily overnight ON RRP and repo amounts (as WL/WA) beside the H.4.1 stock lines; operation-level detail is aux5.**
FRED leaves no-operation business days blank; from each series' first observation these are zero-filled.
*Effect:* H.4.1 stock minus overnight amount = term operations outstanding. Before 2003-02-07 (ON RRP) /
2000-01-03 (repo) the series are absent, not zero.

## Exclusions

**D15. SOFR averages and index not pulled.** FRED's copies silently include the 2018–2020 indicative history
(verified identical to the NY Fed indicative file); if ever added, use the NY Fed API from 2020-03-02 only.

**D16. No SOMA CUSIP-level holdings.** The weekly SOMA aggregates equal the H.4.1 lines (API total = H.4.1
securities held outright minus inflation compensation; H.4.1 MBS includes CMBS). CUSIP detail would be a
module for maturity-profile work.

**D17. Out of scope:** real GDP and real potential, core PCE, unemployment, NROU, NBER dummies, SEP series,
Laubach-Williams and SPF files, SIFMA extracts, the Dallas Fed debt workbook, the money-fund hand file.
The NBER dummies are excluded as series; the corresponding recession start and end dates will be rows of the
events file (D22).

## Indicative history

**D18. Legacy pipe, built even without an immediate consumer.**
Three NY Fed static workbooks, read from checksummed local copies, series prefixed `ind_`, warning on load.
`splice_indicative()` is the only sanctioned join and flags every row.
*Effect:* a plot of SOFR "since 2014" must call `splice_indicative()` explicitly and show the source break.
Any `bind_rows` of `ind_*` with an official series elsewhere is a defect.

**D19. H.3 reserve balances are not pulled.**
H.3 was discontinued in September 2020 and its reserve-balance construct differs from H.4.1 (median gap
~1.4 %, tens of billions in 2008), so it is obsolete for this pipeline. (Revised 2026-11-09: an earlier
build carried it in aux2 under separate names as a possible bridge for 2000–2002; dropped once the core
start was fixed at 2002-12-18.)

## Process

**D20. Series registry is the single source of truth and is generated, not hand-edited.**
Edit `scripts/build_registry.py`, regenerate, rebuild, test. The data dictionary is generated from the same run.

**D21. Tests are plain R (`stopifnot`-style), run at the end of every full build; a failure makes `make_all.R` exit with status 1.**
The tables are saved before the tests run (the tests read them from `data/`), so a failed build leaves the
new tables in place; the log ends with `TESTS FAILED` and the user must inspect before using them. Besides
schema, grid, identities and units, the tests check that discontinued series end by `end_expected`, that live
series are fresh (10/21/75/300 days for d/w/m/q), that no WA postdates its WL, that the calendar and the NY
Fed EFFR publication days coincide in both directions, and that `--units` reads the units string next to the
latest observation on the FRED page.

**D22. Events: one table of point events, one of episodes, both joined to the calendar; both reviewed row by row (2026-11-09).**
`config/events.csv` holds dated events with `event_type`, `memo`, `source`, `confidence`: every FOMC meeting since
2000 (scraped from the Board's calendar pages; a conference call whose statement came the next morning is dated
on the statement day, meeting day in the memo), facility launches and terminations (three terminations inferred
from a final extension release, marked medium), balance-sheet announcements (month-only sources use the first
of the month, said in the memo), and one operations row (2019-09-17 repo stress). `config/episodes.csv` holds
intervals: NBER recessions (peak month start to trough month end), two zero-lower-bound spells (ending on the
liftoff decision day), QE1 to QE3 and the pandemic purchases (announcement day to stated completion), the maturity
extension program as its own kind, two runoff periods, two reserve-management bill-purchase periods (the second
open-ended, extending with each rebuild). Both files are generated by `scripts/build_events.py` from the
provenance copies in `config/sources/`; every decision is a rule in that script.
*Not kept, and why:* policy-rate regime markers (cycle turning points, intermeeting cuts, IOER technical
adjustments) and ON RRP test/regime events and regimes, because all of them are readable off `core_daily`
(target_top/target_bottom, ior, on_rrp_rate) and several ON RRP moves were coordinated with IOR, so they belong
to the analysis of the rates themselves; NBER dummies as a series (D17).
*Effect:* the calendar carries an `event` string per date and one `ep_<kind>` column per episode kind; episodes
within a kind never overlap (tested), so a day has at most one label per kind. Episode edges are exact dates;
any padding for charts is a plotting argument, not data.
