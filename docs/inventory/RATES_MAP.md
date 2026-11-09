# Rates — verified series map (FRED + NY Fed Markets API)

Verified 2026-10-28. FRED IDs checked via series pages (units, frequency, release) and `fredgraph.csv?id=` (first/last obs). NY Fed Markets API checked by downloading each endpoint's full history.

## Sources and their status

| Source | Status | Covers |
|---|---|---|
| FRED, release "FOMC Press Release" (rid=101) | live | DFEDTARU, DFEDTARL, DFEDTAR |
| FRED, release "Interest Rate on Reserve Balances" (rid=185) | live | IORB, IOER, IORR (+ 4 discontinued pre-2015 maintenance-period series) |
| FRED, release "H.15 Selected Interest Rates" (rid=18) | live | DFF, DPCREDIT, Treasury constant maturities, bills, CP, prime (89 series; FRED's table page needs the API key to enumerate) |
| FRED, release "Federal Funds Data" (rid=378, NY Fed) | live | EFFR, EFFR1/25/75/99, EFFRVOL (+ EFFRSD/EFFRL/EFFRH discontinued 2016-02-29). **No OBFR on this release page, but OBFR* IDs exist.** |
| FRED, release "Secured Overnight Financing Rate Data" (rid=445, NY Fed) | live | SOFR, SOFR1/25/75/99, SOFRVOL (+ SOFR30/90/180DAYAVG, SOFRINDEX exist as IDs). **No BGCR, no TGCR on FRED.** |
| FRED, release "Temporary Open Market Operations" (rid=379, NY Fed) | live | RRP/RP amounts by collateral and term, RRPONTSYAWARD |
| NY Fed Markets API `markets.newyorkfed.org/api/rates/...` | live, no key | EFFR, OBFR, SOFR, BGCR, TGCR: rate, 1/25/75/99 pctiles, volume, target range; SOFR averages/index |
| NY Fed Markets API `.../api/rp/...` | live, no key | every repo / reverse repo operation since 2000-07-07, incl. counterparty-type breakdown |
| FRBNY legacy gateway `websvcgatewayx2.frbny.org` (NYFED_rates, NYFED_repos, repomak) | **dead** (no response) | — |

## 1. Policy / administered rates (FRED; all Percent, NSA)

| Variable | ID | Freq | First obs | Last obs | Pulled in tree |
|---|---|---|---|---|---|
| Fed funds target range, upper limit | DFEDTARU | daily, 7-day | 2008-12-16 | present | Normalization24, SRF, MPdiag (3), NYFED_rates, repomak |
| Fed funds target range, lower limit | DFEDTARL | daily, 7-day | 2008-12-16 | present | same |
| Fed funds target rate (pre-range) | DFEDTAR | daily, 7-day | 1982-09-27 | 2008-12-15 | — |
| Interest on reserve balances | IORB | daily, 7-day | 2021-07-29 | present | Normalization24, SRF |
| Interest on excess reserves | IOER | daily, 7-day | 2008-10-09 | 2021-07-28 | Normalization24, SRF, MPdiag, NYFED_rates, repomak |
| Interest on required reserves | IORR | daily, 7-day | 2008-10-09 | 2021-07-28 | SRF |
| ON RRP award rate (Treasury) | RRPONTSYAWARD | daily, bus. days | 2013-09-23 | present | Normalization24, SRF, ONRRP2023 |
| Discount window primary credit rate | DPCREDIT | daily, 7-day | 2003-01-09 | present | Normalization24, SRF |

Splices needed for a long series: DFEDTAR → DFEDTARU/L at 2008-12-16; IOER (or IORR) → IORB at 2021-07-29 (IOER = IORR from 2008-12 onward, so either works).
Proxies used in old code and no longer needed: DFEDTARU as "IOR" and DFEDTARL as "ON RRP rate" (MPdiag, NYFED_rates).

## 2. Money market reference rates

### 2a. On FRED (Percent or $bn, NSA, daily business days)

| Variable | Rate | 1st pct | 25th | 75th | 99th | Volume ($bn) | First obs | Pulled in tree |
|---|---|---|---|---|---|---|---|---|
| Effective fed funds rate (NY Fed, FR 2420) | EFFR | EFFR1 | EFFR25 | EFFR75 | EFFR99 | EFFRVOL | EFFR 2000-07-03; percentiles & volume 2016-03-01 | SRF (EFFR); pctiles/vol: Normalization24, SRF, MPdiag (3), repomak |
| Overnight bank funding rate | OBFR | OBFR1 | OBFR25 | OBFR75 | OBFR99 | OBFRVOL | 2016-03-01 | — (only via dead gateway) |
| SOFR | SOFR | SOFR1 | SOFR25 | SOFR75 | SOFR99 | SOFRVOL | 2018-04-03 | SRF (all), ONRRP2023 (SOFR, SOFRVOL) |
| SOFR averages / index | SOFR30DAYAVG (2018-05-02), SOFR90DAYAVG (2018-07-02), SOFR180DAYAVG (2018-10-01), SOFRINDEX (2018-04-02) | | | | | | | — |
| Broad General Collateral Rate | **not on FRED** | | | | | | | — |
| Tri-Party General Collateral Rate | **not on FRED** | | | | | | | — |
| Fed funds effective, Board H.15 version | DFF (daily 7-day, 1954-07-01) ; FEDFUNDS (monthly avg, 1954-07-01) | | | | | | | DFF: Normalization24, MPdiag (9), repomak; FEDFUNDS: MPdiag |

Note: FRED's SOFR starts 2018-04-03; the NY Fed API has 2018-04-02 as the first observation. DFF carries weekends/holidays as repeated values; EFFR is business days only.

### 2b. NY Fed Markets API (one call per rate type or `all`; CSV or JSON; no key)

Endpoints: `GET https://markets.newyorkfed.org/api/rates/{unsecured|secured}/{effr|obfr|sofr|bgcr|tgcr|all}/search.csv?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD`
Columns: Effective Date, Rate Type, Rate (%), 1st/25th/75th/99th Percentile (%), Volume ($Billions), Target Rate From/To (%), Intra Day Low/High (%), Standard Deviation (%), 30/90/180-Day Average SOFR, SOFR Index, Revision Indicator, Footnote ID.

| Rate type | First obs | Fields populated | Rows (to 2026-10-27) |
|---|---|---|---|
| EFFR | 2000-07-03 | 2000–2016-02: rate, target, intraday low/high, std dev. From 2016-03-01: rate, percentiles, volume, target range | 6,614 |
| OBFR | 2016-03-01 | rate, percentiles, volume | 2,678 |
| SOFR | 2018-04-02 | rate, percentiles, volume | 2,140 |
| BGCR | 2018-04-02 | rate, percentiles, volume | 2,140 |
| TGCR | 2018-04-02 | rate, percentiles, volume | 2,140 |
| SOFRAI | 2020-03-02 | 30/90/180-day averages, index | 1,663 |

This is the replacement for the dead gateway used by NYFED_rates and for the hand-downloaded `RepoRateSearch-*.xls` / `HistorySOFR.xlsx` in repomak (the pre-2018 "indicative" TGCR/BGCR/SOFR history 2014-08-22 to 2018-03-29 is **not** in the API; the repomak xlsx is the only copy in the tree).

## 3. Open market operations (ON RRP / repo)

### 3a. FRED, release "Temporary Open Market Operations" (rid=379; daily, Billions of USD, NSA)

Reverse repos (table eid=147896): RRPTTLD total; RRPTSYD Treasury; **RRPONTSYD** overnight Treasury (first obs 2003-02-07); RRPTMTSYD term Treasury; RRPAGYD / RRPONAGYD / RRPTMAGYD agency; RRPMBSD / RRPONMBSD / RRPTMMBSD MBS; RRPONTSYAWARD award rate (%).
Repos (eid=147907): RPTTLD total; RPTSYD / **RPONTSYD** (first obs 2000-01-03) / RPTMTSYD Treasury; RPAGYD / RPONAGYD / RPTMAGYD agency; RPMBSD / RPONMBSD / RPTMMBSD MBS.
None pulled in the tree (ON RRP take-up was always taken from H.4.1 WREPODEL/WLRRAOL instead; the daily series is here).

### 3b. NY Fed Markets API

- `.../api/rp/results/search.csv?startDate=&endDate=` — every operation since **2000-07-07** (8,262 ops: 4,809 repo, 3,426 reverse repo, 26 matched sale-purchase). Per operation: dates, term, method, operation limit, participating/accepted counterparties, and per collateral (Tsy/Agy/MBS/Oth) submitted, accepted, min/max bid, offering, stop-out, award, weighted-average, high, low rates. SRF pulls this from 2021-01-01.
- `.../api/rp/reverserepo/propositions/search.csv` — ON RRP accepted amounts by counterparty type (Bank, GSE, MMF, PD) per operation; operations listed from 2003-02-07, breakdown populated from **2013-09-23**. Replaces repomak's hand-downloaded "Reverse Repo Data by Counterparty Type.xlsx" (which ended 2018-03-29).
- Legacy `tomo/retrieveXmlLastN` (NYFED_repos, repomak) is dead; `rp/results` is the successor.

## 4. Treasury yields (FRED H.15; Percent, NSA; MPdiag only)

| ID | Variable | Freq | First obs |
|---|---|---|---|
| DGS1MO, DGS3MO, DGS6MO | 1-, 3-, 6-month constant maturity | daily | 2001-07-31, 1981-09-01, 1981-09-01 |
| DGS1, DGS2, DGS5, DGS10 | 1-, 2-, 5-, 10-year constant maturity | daily | 1962-01-02, 1976-06-01, 1962-01-02, 1962-01-02 |
| DFII10 | 10-year TIPS constant maturity | daily | 2003-01-02 |
| DTB4WK, DTB3 | 4-week, 3-month bill secondary market | daily | 2001-07-31, 1954-01-04 |
| GS10, TB3MS | 10-year CM, 3-month bill, monthly avg | monthly | 1953-04-01, 1934-01-01 |

Pulled: DGS1/2/5/10, DFII10, GS10, TB3MS (MPdiag). Others listed for completeness.

## 5. Business-day rule (pipeline requirement, 2026-10-28)

Rates are kept on business days only, so month/quarter/year ends resolve to the last business day on or before the calendar end with no weekend/holiday rows to trip over.

Which series carry non-business days (checked on full downloads):

| Series | Weekend rows | Holiday rows | Treatment |
|---|---|---|---|
| DFF, DFEDTARU, DFEDTARL, IORB, IOER, IORR | yes (7-day) | yes | filter to calendar |
| DPCREDIT, RRPONTSYAWARD, RRPONTSYD, DGS*, DTB* on FRED | none | present as blank values ("." in CSV) | drop blank rows / filter to calendar |
| EFFR on FRED | none | 259 blank-value rows (holidays) | drop blanks |
| EFFR on NY Fed API | one spurious Sunday row (2003-07-20, duplicate of 07-21) | none | drop weekend dates |
| OBFR, SOFR, BGCR, TGCR on NY Fed API; the three static NY Fed xlsx files | none | none | as is |

Calendar anchor: the set of dates on which the NY Fed publishes EFFR (API, 2000-07-03 onward) is FRED's EFFR non-blank dates minus 2002-02-18 plus six days FRED leaves blank (2001-03-27, 2003-10-10, 2003-10-30, 2003-10-31, 2006-11-06, 2006-11-14; corrected 2026-11-09, see config/calendar_inclusions.csv), and matches OBFR dates; SOFR is absent on SIFMA closures. Use it as the money-market business-day calendar from 2000-07-03. For earlier dates (DFF/FEDFUNDS history, Treasury yields back to 1962), use FRED DTB3 non-blank dates (1954-01-04 onward) as the proxy calendar.

Verified: last business day per month from this calendar gives e.g. 2026-02-27, 2026-05-29, 2025-08-29, 2024-03-29, 2023-12-29.

## 6. Static NY Fed history files (no API; one-off reads)

Found on https://www.newyorkfed.org/markets/reference-rates/additional-information-about-reference-rates, section "Additional Reference Rate Data". Copies and a README are in `_data_inventory/nyfed_static/`.

| File | Content | Range | Notes |
|---|---|---|---|
| `Data Release.xlsx` → `indicative_repo_2014_2018.xlsx` | indicative TGCR/BGCR/SOFR volume-weighted median (bp), volumes ($bn), 3-month geometric mean | 2014-08-22 to 2018-03-29, 899 business days | MD5-identical to repomak `HistorySOFR.xlsx`; rates in **basis points** (repomak divides by 100) |
| `ff-volumes-oct2006-feb2016.xlsx` | brokered fed funds 1/25/50/75/99 percentile rates (%) and volume ($bn) | 2006-10-02 to 2016-02-29, 2,364 business days | extends EFFR percentiles/volume back from 2016-03-01; brokered-only universe, not FR 2420 |
| `historical_indicative_sofr_avg_ind_data.xlsx` | indicative SOFR index and 30/90/180-day averages | 2018-04-02 to 2020-02-28 | official SOFRAI starts 2020-03-02 |

## 7. Unit convention and splice rule (decided 2026-10-28)

- All dollar quantities in **millions of USD** (H.4.1 native). Convert at load: FRED EFFRVOL/OBFRVOL/SOFRVOL ($bn ×1000); NY Fed API `Volume ($Billions)` and every `($Billions)` column in `rp/results` and `rp/reverserepo/propositions` (×1000); FRED release rid=379 RRP*/RP* amounts ($bn ×1000); Volumes sheets of the static files (×1000).
- All rates in **basis points**. FRED and NY Fed API rates are percent → ×100 at load. The indicative repo "VWM Rates" sheet is already basis points (no conversion).
- **Indicative and brokered history is never spliced silently** onto official series (indicative TGCR/BGCR/SOFR 2014–2018; brokered fed funds percentiles/volume 2006–2016; indicative SOFR averages 2018–2020). They are loaded into separately named objects with a `source` flag, and any join emits a warning.

### 7a. FRED trap: SOFR averages and index (added 2026-11-02)

FRED SOFR30DAYAVG / SOFR90DAYAVG / SOFR180DAYAVG / SOFRINDEX start 2018-05-02 / 2018-07-02 / 2018-10-01 / 2018-04-02 and are **identical to the NY Fed indicative file** (`indicative_sofr_avg_2018_2020.xlsx`) before 2020-03-02 (checked 2018-05-02, 2019-03-15, 2019-12-31, 2020-02-28: 30-day average and index match to all digits). The NY Fed API `rates/secured/sofrai/search.csv` has official values only, from 2020-03-02. FRED has spliced the indicative history without a flag. Pipeline rule: take averages/index from the API (official) and from the legacy pipe (indicative), never from FRED unspliced.

## 8. Gaps and replacements relative to the current code

1. OBFR, BGCR, TGCR percentiles/volumes: only source in the tree was the dead gateway → NY Fed API `rates/...` (OBFR also on FRED).
2. `Reserves_Limits/data/effr|obfr|repo|policy.Rdata` were made by NYFED_rates from the dead gateway (ending 2021-04) → regenerate from FRED/API.
3. repomak manual spreadsheets (TOMO export, RRP by counterparty type, RepoRateSearch) → `rp/results`, `rp/reverserepo/propositions`, `rates/secured`. HistorySOFR.xlsx (indicative repo rates 2014–2018) has no API replacement.
4. IOER→IORB and DFEDTAR→DFEDTARU/L splices should be done once in the pipeline, not per project.
5. DFF vs EFFR: old code mixes them under the label "EFFR". Same values on business days; DFF fills weekends.
