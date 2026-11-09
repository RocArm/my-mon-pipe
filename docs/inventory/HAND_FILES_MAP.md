# Hand-dropped files — verdicts for the pipeline

Reviewed 2026-11-02 against the scope decisions so far (nominal GDP + potential; Treasury debt; DPCREDIT only for the discount window; no CUSIP-level SOMA; no SIFMA; no real-side / labour / r* work).

Verdict codes: **API** = replaced by a live keyless pull already verified; **FRED** = replaced by a FRED series; **KEEP** = stays a manual drop (no live source); **OUT** = outside the chosen scope, not carried; **ORPHAN** = read by no script.

| # | File | Content | Verdict | Replacement / note |
|---|---|---|---|---|
| 1 | `Armenter_SlowSmooth/SOMAprojection/July2017projections.csv` (+ xlsx, pdf) | projected SOMA redemptions, Treasury and MBS, $bn/month, 2017-01 → 2023-07 | **KEEP** (project module) | No API. Current equivalents are the OMO annual-report data workbooks `newyorkfed.org/medialibrary/media/markets/omo/omoYYYY-data.xlsx` (2012 → 2025); see SOMA_MAP §5. `January2019projections.csv` does not exist anywhere. |
| 2 | `ONRRP2023/data/manuals/MSPD.csv` | marketable debt by class held by public, $mn, 2019-01 → 2023-09 | **API** | Treasury FiscalData `v1/debt/mspd/mspd_table_1`, 2001-01 → present; MACRO_DEBT_MAP §3b. |
| 3 | `ONRRP2023/data/MMF data Ben v2.csv` | monthly 2022-01 → 2023-10; columns Date, ONRRP Take up ($mn), Market repo volume, T-bills held outright, T-bills held by public; colleague-built from ICI data, read by `figures_Isaac.R:62` | **KEEP** (project module) or **OUT** | Upstream not reproducible: OFR MMF Monitor site is live but its data API (`data.financialresearch.gov/mmf/v1/...`) answered 403 on every documented path today; ICI monthly tables are not keyless. Two columns are reproducible: ON RRP take-up (NY Fed `rp/results`, MMF share via `rp/reverserepo/propositions`) and T-bills held by public (MSPD). The MMF repo volume and MMF T-bill holdings columns are not. |
| 4 | `Reserves_Limits/data/data_SIFMA.csv` (+ monthly/annual SIFMA csv/xlsx) | Treasury net issuance and outstanding, $bn | **OUT** | User dropped SIFMA 2026-11-02; MSPD covers outstanding. |
| 5 | `Reserves_Limits/data/effr.Rdata, obfr.Rdata, repo.Rdata` | EFFR/OBFR/SOFR-BGCR-TGCR percentiles and volumes, 2017-01 → 2021-04, from the dead FRBNY gateway | **API** | NY Fed Markets API `rates/{unsecured\|secured}/.../search.csv` — re-verified live 2026-11-02 (EFFR from 2000-07-03, OBFR 2016-03-01, SOFR/BGCR/TGCR 2018-04-02); RATES_MAP §2b. |
| 6 | `Reserves_Limits/data/policy.Rdata` | target range top/bottom, IOER, ON RRP rate, 2012 → 2021 | **FRED** | DFEDTARU, DFEDTARL, IOER/IORB, RRPONTSYAWARD; RATES_MAP §1. |
| 7 | `repomak/.../manual/tomo-01012017-06292018.xls` | ON RRP operations, counterparties and submissions | **API** | `rp/results/search.csv` (all ops since 2000-07-07). |
| 8 | `repomak/.../manual/Reverse Repo Data by Counterparty Type.xlsx` | ON RRP take-up by Bank/GSE/MMF/PD, 2013-09-23 → 2018-03-29 | **API** | `rp/reverserepo/propositions/search.csv` (breakdown from 2013-09-23). |
| 9 | `repomak/.../manual/RepoRateSearch-04022018-08062018.xls` | TGCR/BGCR/SOFR rates, percentiles, volume | **API** | `rates/secured/all/search.csv`; SOFR* also on FRED. |
| 10 | `repomak/.../manual/HistorySOFR.xlsx` sheet "VWM Rates" | indicative TGCR/BGCR/SOFR, bp, 2014-08-22 → 2018-03-29 | **KEEP** (flagged) | Static NY Fed file, identical copy saved at `_data_inventory/nyfed_static/indicative_repo_2014_2018.xlsx`. Never spliced onto official series without the warning (memory rule). |
| 11 | `repomak/codes/calibration/datahistogram.csv` | FF-rate deviation histogram, hand-imputed | **OUT** | Origin ambiguous; MATLAB calibration input, not data. |
| 12 | `MPdiag/input/Laubach_Williams_*.xlsx`, `Holston_Laubach_Williams_real_time_estimates.xlsx` | r* estimates and vintages | **OUT** | r* work not in scope (real-side series excluded 2026-11-02). |
| 13 | `MPdiag/input/lubik_matthes_natural_rate_interest.xlsx` | Richmond Fed natural rate | **OUT** | as above |
| 14 | `MPdiag/input/rbar.smoothed.csv` | Johannsen-Mertens r-bar | **OUT** | as above |
| 15 | `MPdiag/input/Median_PCE10_Level.xlsx` (and unreferenced `Median_CPI10_Level.xlsx`) | SPF median 10-yr inflation expectations | **OUT** | dropped with the SEP/NBER set 2026-11-02 |
| 16 | `ReservesTrendCo/DPSACBM027SBOG.xls`, `Balance Sheet ben.xls` | FRED graph export of deposits + hand-pasted reserves and nominal GDP, ratios in-sheet | **FRED** | DPSACBM027SBOG (H.8 core), TOTRESNS (H.3, $bn, 1959 →), GDP; no code reads these files anyway. |
| 17 | `Dates_BalanceSheet.csv` / `.R` (Normalization24, ReservesTrendCo) | four hand-typed balance-sheet event dates 2019-05-02 → 2022-05-04 | **KEEP** (config, not data) | Belongs in a pipeline config file of policy event dates, extended as needed. |

## Raw files read by no script (ORPHAN)

NY Fed TOMO / fed funds exports 2014–2016 and the repomak RED-paper test spreadsheets (repomak `ffdata/`), Potter speech chart data, SIFMA workbooks (Reserves_Limits), Haver `ED.xlsx`, `ONRRP2023/data/manuals/govdebt.xlsx` (Dallas Fed; market-value columns on FRED as MVGFD027MNFRBDAL, MVPHGFD027MNFRBDAL, MVMTD027MNFRBDAL; par-value columns not on FRED), SPF CPI10, extra LW/HLW vintages. None carried.

## Net result

Manual inputs the pipeline still needs: **#10** (indicative repo history, flagged) and **#17** (event-date config). **#1** and **#3** survive only inside their project modules if those projects are revived. Everything else is a live FRED, NY Fed API or FiscalData pull or is out of scope.
