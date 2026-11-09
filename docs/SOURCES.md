# Sources

Every endpoint the pipeline reads, how it was verified, and the traps found. The detailed verification
notes (series-by-series ranges, identity checks, reconciliations) are the inventory maps copied into
`docs/inventory/`; they were written against live sources on 2026-10-27 to 2026-11-08.

| Source | Access | Used by | Verified |
|---|---|---|---|
| FRED, keyless CSV: `https://fred.stlouisfed.org/graph/fredgraph.csv?id=<ID>` | GET, no key | core, aux2, aux3, aux4 | 2026-11-08 |
| FRED series pages: `https://fred.stlouisfed.org/series/<ID>` | GET, no key | `tests --units` (unit-string drift) | 2026-11-02 |
| NY Fed Markets API, rates: `https://markets.newyorkfed.org/api/rates/{unsecured,secured}/{effr,obfr,sofr,bgcr,tgcr}/search.csv?startDate=&endDate=` | GET, no key | aux1 | 2026-11-08 |
| NY Fed Markets API, operations: `.../api/rp/results/search.csv`, `.../api/rp/reverserepo/propositions/search.csv` | GET, no key | aux5 | 2026-11-08 |
| Treasury FiscalData: `https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v1/debt/mspd/mspd_table_1` | GET, no key, paged (`page[size]`, `page[number]`; brackets percent-encoded) | aux3 | 2026-11-08 |
| NY Fed static workbooks (three), local copies in `static/` with MD5 in `config/static_files.csv` | file | legacy | 2026-10-28 |

Not used, by decision: Haver DLX (inherited projects only), the dead FRBNY XML gateway
`websvcgatewayx2.frbny.org`, the FRED REST API (would need a key), NY Fed SOMA endpoints (aggregates equal
H.4.1; see `inventory/SOMA_MAP.md`), the OFR money-fund monitor (no reachable API).

## Behaviour of each source

### FRED
- Daily series carry weekend/holiday rows as `.` (missing) for market rates, but **some administered series
  carry weekday holidays with a repeated value** (DPCREDIT, RRPONTSYD, RPONTSYD) and the 7-day policy series
  (DFEDTAR*, IOER/IORR/IORB) carry weekends. The business-day join removes all of these.
- EFFR has a value on 2002-02-18 (Presidents' Day) that the NY Fed never published; excluded via
  `config/calendar_exclusions.csv`. No other FRED-only date exists since 2000 (checked against the API).
- Operation amounts (RRPONTSYD, RPONTSYD) are blank on business days without an operation; zero-filled from
  first observation (D14).
- H.4.1: all series are millions, NSA, weekly, first observation 2002-12-18. Until early 2025 FRED served
  WRESBAL, WCURCIR, WTREGEN, WSECOUT in billions with history to the 1980s; that history is gone from the
  current endpoint (ALFRED vintages would recover it). This is why the `--units` test exists.
- SOFR on FRED starts 2018-04-03; the NY Fed has 2018-04-02.
- FRED's SOFR averages/index (SOFR30/90/180DAYAVG, SOFRINDEX) silently include the 2018–2020 indicative
  history. Not pulled (D15).
- H.8: balance-sheet lines are billions, the memo items H8B3092/H8B3094 are millions; weekly from 1973-01-03
  (large/small bank splits from 1985-04-03; fed funds sold memo from 2010-01-06).
- Debt: FYGFDPUN and GFDEBTN are millions, FDHBFRBN and FDHBPIN are billions. NGDPSAXDCUSQ equals GDP/4
  (quarterly rate) and is not used.
- **Transport:** FRED drops requests that carry a custom `User-Agent` and fails on HTTP/2 connection reuse;
  the loader sets no user agent and forces HTTP/1.1.

### NY Fed Markets API
- Rates CSV columns: `Effective Date, Rate Type, Rate (%), 1st/25th/75th/99th Percentile (%), Volume ($Billions),
  Target Rate From/To (%), Intra Day - Low/High (%), Standard Deviation (%), 30/90/180-Day Average SOFR,
  SOFR Index, Revision Indicator, Footnote`. Percentiles and volume exist from 2016-03-01 (FR 2420); before
  that EFFR rows carry intraday low/high and std dev. One spurious Sunday row (2003-07-20) is dropped by the
  calendar join. 35 EFFR days in 2000–2001 and one OBFR day (2019-07-18) are flagged revised; FRED carries the
  revised values (verified identical on every common day).
- Operations: one row per operation, 72 columns; amounts in `($Billions)`, rates in `(%)`, and
  `Amt At Stop-Out (%)` which is an allotment **share**, not a rate (kept in percent as `(pct_share)`).
  Counterparty-type split of ON RRP is published with roughly a quarter's lag.
- SOMA (not used): `soma/summary.csv` weekly from 2003-07-09 equals H.4.1 Wednesday levels line by line,
  except total (excludes TIPS inflation compensation) and MBS (excludes CMBS); as-of dates shift to Tue/Thu
  on holiday Wednesdays.

### Treasury FiscalData
- MSPD table 1: monthly, month-end dated, 2001-01-31 onward, 15 to 21 type/class rows per month, millions.
  Fields `debt_held_public_mil_amt`, `intragov_hold_mil_amt`, `total_mil_amt`. Replaces the hand-downloaded
  CSV the ONRRP2023 project used.

### NY Fed static workbooks (legacy pipe)
See `docs/inventory/NYFED_STATIC_FILES.md` for URLs and layouts. Indicative TGCR/BGCR/SOFR rates are already
basis points; brokered fed funds rates are percent; all volumes are billions. Headers start with digits
(`1st Percentile Rate`, `30-Day Average SOFR`), which R renames with an `X` prefix; the loader matches on
substrings for that reason.

## Events and episodes (config/sources/)

| File | Content | Used for |
|---|---|---|
| `events_candidate_2026-11-09.csv` | 360 candidate rows collected 2026-11-09 by an agent from the Board's FOMC calendar pages (fomccalendars.htm, fomchistoricalYYYY.htm for 2000 to 2020), about 95 Board press releases and implementation notes, and FRED USREC; every row has a URL and a confidence | base of `events.csv`; balance-sheet dates behind the episodes |
| `events_candidate_2026-11-09_notes.md` | the agent's per-type sources, extraction method and ambiguities | provenance |
| `fomc_parsed_2026-11-09.csv` | raw parsed FOMC list including future and cancelled meetings | provenance |
| `Dates_BalanceSheet_Normalization24.csv` | four hand-typed dates from the inherited Normalization24 project | two merged into sourced rows, two kept as hand rows |

`scripts/build_events.py` turns these into `config/events.csv` and `config/episodes.csv`; the rules in it are the
record of the review decisions (D22).

## Inventory maps (evidence)

| File | What it establishes |
|---|---|
| `inventory/H41_FRED_MAP.md` | every H.4.1 Table 1/1A/5 FRED ID, WA/WL pairing, identities checked, the 2025 unit change |
| `inventory/H41_PAIRS.md` | short pair list, Haver equivalents, ranges requested per inherited project |
| `inventory/RATES_MAP.md` | policy, reference and Treasury rates; API endpoints; business-day rules; the SOFR-averages trap |
| `inventory/MACRO_DEBT_MAP.md` | GDP and debt series, FiscalData replacement for MSPD, scope decisions |
| `inventory/DISCOUNT_WINDOW_MAP.md` | DPCREDIT calendar behaviour, pre-2003 regime, H.4.1 loan lines, Board loan-level files |
| `inventory/SOMA_MAP.md` | SOMA API endpoints and the reconciliation with H.4.1 |
| `inventory/HAND_FILES_MAP.md` | verdict on every hand-dropped file in the inherited projects |
| `inventory/NYFED_STATIC_FILES.md` | the three legacy workbooks: URLs, layout, units |

The maps reference the inherited project tree under `C:\Work\WorkLocal\ScrubRatesBS`, which is not part of
this repository.
