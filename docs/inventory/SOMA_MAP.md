# NY Fed SOMA holdings — pulls in the tree and verified sources

Verified 2026-11-02 against the live NY Fed Markets API (`https://markets.newyorkfed.org/api/soma/...`, keyless, CSV) and FRED H.4.1.

## 1. What the projects pull

| Variable | Source | Freq | Range | Pulled in |
|---|---|---|---|---|
| SOMA total holdings, agency MBS holdings (Haver FSOMA, FSUAMBS, WEEKLY db) | Haver DLX | weekly | 2000-01-01 → 2019-08-01 | Armenter_SlowSmooth (2 scripts) |
| SOMA Treasury notes & bonds by CUSIP (par, maturity, coupon, % outstanding, weekly change) | NY Fed API `soma/non-mbs/get/notesbonds/asof/{date}.csv`; date list from `soma/non-mbs/list/asof.csv` | weekly snapshots sampled at quarter ends | 2013-12-31 → 2016-12-28 (13 dates) + hand downloads 2014/15/16-12 | window (1 active, several superseded) |
| SOMA aggregates via H.4.1 (WSECOUT/WSHOSHO, WSHOTSA/L, WSHOBA/L, WMBSEC/WSHOMCB, WFEDSEC/FEDDT) | FRED | weekly | various | Norm24, Bridge2025, SRF, ONRRP2023, Reserves_Limits, TrendReserves — covered in H41_FRED_MAP |
| Projected SOMA redemptions, Treasury and MBS, $bn/month | hand-built csv from NY Fed July-2017 projections xlsx | monthly | 2017-01 → 2023-07 | Armenter_SlowSmooth; a January-2019 csv is referenced but missing |

The `window` endpoint `non-mbs/list/asof.csv` now returns HTTP 400. Replacement: `soma/asofdates/list.csv`.

## 2. Live API endpoints (all HTTP 200 on 2026-11-02)

| Endpoint | Content | Range | Units |
|---|---|---|---|
| `soma/summary.csv` | one row per as-of date: Total, MBS, TIPS, FRN, TIPS Inflation Compensation, Notes & Bonds, Bills, Agencies, CMBS | 2003-07-09 → 2026-10-28, 1,217 rows | **dollars** → ÷1e6 to $mn |
| `soma/asofdates/list.csv`, `soma/asofdates/latest.csv` | as-of dates (m/d/Y) | same 1,217 dates | — |
| `soma/non-mbs/get/{all\|bills\|notesbonds\|tips\|frn}/asof/{YYYY-MM-DD}.csv` | holdings by CUSIP: As Of Date, CUSIP, Security Type, Security Description, Term, Maturity Date, Issuer, Spread (%), Coupon (%), Current Face Value, Par Value, Inflation Compensation, Percent Outstanding, Change From Prior Week, Change From Prior Year, is Aggregated | any as-of date from 2003-07-09 (165 CUSIPs then, 433 now) | dollars; coupon percent |
| `soma/non-mbs/get/monthly.csv` | the same CUSIP detail for the **last as-of date of each month** | 2003-07-30 → 2026-10-28, 280 months, 82,668 rows | dollars |
| `soma/non-mbs/get/release_log.csv` | release date ↔ as-of date, last 13 | — | — |
| `soma/mbs/get/asof/{YYYY-MM-DD}.csv` | agency MBS by CUSIP (Security Description e.g. "UMBS MORTPASS 2% 10/51", Term 30yr/15yr, Current Face Value) | first non-empty 2009-01-14; 8,422 CUSIPs on 2026-10-28 | dollars |
| `soma/mbs/get/release_log.csv` | as above for MBS | — | — |

Not available: `mbs/get/monthly.csv` (400), any per-CUSIP agency-debt or CMBS endpoint (400 under every name tried); those two classes appear only as totals in `summary.csv`. Security type must be lower-case in the URL (`notesbonds`, `frn`, `tips`, `bills`, `all`); the `.csv` suffix is required.

## 3. Reconciliation with FRED H.4.1 Wednesday levels ($mn), checked 2010-06-30, 2016-12-28, 2021-12-29, 2026-10-21, 2026-10-28

| SOMA summary column(s) | = H.4.1 ID | Match |
|---|---|---|
| Bills | WSHOBL | exact |
| Notes & Bonds + FRN | WSHONBNL (nominal notes & bonds) | exact |
| TIPS | WSHONBIIL | exact |
| TIPS Inflation Compensation | WSHOICL | exact from 2010 (2003-07-09 differs: 929 vs 1,479) |
| Bills + N&B + FRN + TIPS + IC | WSHOTSL (Treasuries total) | exact |
| MBS + CMBS | WSHOMCB | exact (H.4.1 MBS **includes** CMBS) |
| Agencies | WSHOFADSL (= FEDDT) | exact |
| **Total** | WSHOSHO | **SOMA Total = WSHOSHO − Inflation Compensation** (e.g. 2026-10-28: 6,355,840 vs 6,462,451, diff 106,611 = IC) |

So the API summary and FRED are the same numbers at the same par/face basis; FRED is the simpler source for weekly aggregates, the API is needed only for CUSIP-level detail (maturity profile, coupons, % of issue held).

## 4. Calendar quirks

- As-of dates are Wednesdays except when the Wednesday is a holiday: 12 Tuesdays and 2 Thursdays in 1,217 dates (e.g. 2007-07-03, 2009-11-10, 2012-07-03, 2013-12-24, 2013-12-31). FRED H.4.1 keeps the nominal Wednesday. Join by week (nearest ±1 day), not by exact date.
- 22 non-7-day gaps, all from those shifts; no missing weeks found.

## 5. SOMA projections (static, no API)

NY Fed page `https://www.newyorkfed.org/markets/annual_reports` (HTTP 200). Links:
- `/medialibrary/media/markets/omo/July2017projections.xlsx` — the file SlowSmooth's csv was built from.
- `/medialibrary/media/markets/omo/SOMA-Projections-Data-2018Addendum-092019.xlsx` — the Sept-2019 addendum (the "January 2019 projections" SlowSmooth references do not appear as a separate file).
- Open Market Operations annual report data: `omo2012.xls`, `omo2013.xlsx`, `omo2014-xls.xlsx` … `omo2021-xls.xlsx`, `omo2022-data.xlsx` … `omo2025-data.xlsx` (one workbook per year with the report's chart data, incl. the portfolio projections of that year).
These stay hand-dropped inputs; if a project needs projections, download the year's `omoYYYY-data.xlsx` into that project's manual folder and record the URL.

## 6. Provisional split

- **Core:** nothing from the API. The weekly SOMA aggregates are already in the H.4.1 core pull (WSHOSHO, WSHOTSL, WSHOBL, WSHONBNL, WSHONBIIL, WSHOICL, WSHOFADSL, WSHOMCB, WA and WL), identical to the API summary.
- **Project-specific module (window, SlowSmooth-type maturity work):** `soma/non-mbs/get/all/asof/{date}.csv` for chosen dates, or `non-mbs/get/monthly.csv` for the month-end history; `soma/mbs/get/asof/{date}.csv` if MBS detail is needed; Haver FSOMA/FSUAMBS replaced by FRED.
- **Hand files:** OMO annual report workbooks for projections.
