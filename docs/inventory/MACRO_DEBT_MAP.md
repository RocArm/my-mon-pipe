# Macro and Treasury debt series — verified map

All FRED IDs re-fetched from `fred.stlouisfed.org/graph/fredgraph.csv?id=` and series pages on 2026-11-02. Ranges are as served today.

## 1. National accounts and potential output (quarterly)

| Series | ID | Units on FRED | Range | Pulled in | Pipeline unit |
|---|---|---|---|---|---|
| Nominal GDP (BEA) | GDP | $bn, SAAR | 1947Q1 → 2026Q3 | Normalization24 | ×1000 → $mn |
| Nominal GDP (IMF IFS copy) | NGDPSAXDCUSQ | **millions** of domestic currency, SA, quarterly rate (not annualised) | 1950Q1 → 2026Q2 | TrendReserves; ReservesTrendCo xls | $mn as is. **Redundant with GDP**: GDP/4 ≈ this series. Recommend dropping in favour of GDP. |
| Nominal potential GDP (CBO) | NGDPPOT | $bn, SAAR | 1949Q1 → **2036Q4** (projections) | Bridge2025, Reserves_Limits, TrendReserves | ×1000 → $mn |
| Real GDP | GDPC1 | $bn chained 2017, SAAR | 1947Q1 → 2026Q3 | MPdiag | ×1000 |
| Real potential GDP (CBO) | GDPPOT | $bn chained 2017 | 1949Q1 → 2036Q4 | MPdiag | ×1000 |
| Core PCE inflation | DPCCRV1Q225SBEA | percent change q/q SAAR | 1959Q2 → 2026Q3 | MPdiag | ×100 → bp (per convention), or keep as pct — flag for user |
| Unemployment rate | UNRATE | percent, SA, monthly | 1948-01 → 2026-09 | MPdiag | ×100 → bp |
| Noncyclical rate of unemployment (CBO) | NROU | percent, quarterly | 1949Q1 → 2036Q4 | MPdiag | ×100 → bp |
| Nominal GDP (Haver USNA:GDP) | Haver | $bn SAAR | 2015Q4 → 2019Q2 | Armenter_SlowSmooth | replace with FRED GDP |

## 2. Recession and policy expectations

| Series | ID | Units | Range | Pulled in |
|---|---|---|---|---|
| NBER recession indicator, monthly | USREC | 0/1 | 1854-12 → 2026-09 | MPdiag |
| NBER recession indicator, quarterly | USRECQ | 0/1 | 1854Q4 → 2026Q3 | MPdiag |
| SEP longer-run fed funds, median | FEDTARMDLR | percent, per SEP meeting | 2012-01-25 → 2026-09-16 (59 obs) | MPdiag |
| SEP longer-run, central tendency high / low | FEDTARCTHLR / FEDTARCTLLR | percent | 2015-06-17 → 2026-09-16 (45 obs) | MPdiag |
| SEP longer-run, range high / low | FEDTARRHLR / FEDTARRLLR | percent | 2015-06-17 → 2026-09-16 | MPdiag |

SEP series are dated by FOMC meeting, irregular. Convert percent ×100 → bp. These are rates but not daily: do not apply the business-day calendar join, just keep meeting dates.

## 3. Treasury debt

### 3a. FRED (Treasury Bulletin / Financial Management Service), quarterly, end of quarter

| Series | ID | Units on FRED | Range | Pulled in |
|---|---|---|---|---|
| Federal debt held by the public | FYGFDPUN | **$mn** | 1970Q1 → 2026Q2 | Reserves_Limits (÷1000 in code) |
| Federal debt held by Federal Reserve Banks | FDHBFRBN | **$bn** | 1970Q1 → 2026Q2 | Reserves_Limits |
| Federal debt held by private investors | FDHBPIN | $bn | 1970Q1 → 2026Q2 | — (candidate) |
| Federal debt, total public debt | GFDEBTN | $mn | 1966Q1 → 2026Q2 | — (candidate) |

Unit trap: the two series Reserves_Limits pulls together are in different units (mn vs bn). Convert FDHBFRBN ×1000.

### 3b. Monthly Statement of the Public Debt (MSPD) — hand file → Treasury FiscalData API

ONRRP2023 reads a hand download `data/manuals/MSPD.csv` (Jan 2019 → Sep 2023, 894 rows) and keeps marketable Bills, Notes, Bonds, debt held by the public, $mn.

Live replacement (verified 2026-11-02, keyless):
```
https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v1/debt/mspd/mspd_table_1
   ?sort=record_date&page[size]=10000
```
Fields: `record_date, security_type_desc, security_class_desc, debt_held_public_mil_amt, intragov_hold_mil_amt, total_mil_amt, src_line_nbr, record_fiscal_year, ..., record_calendar_day`. Monthly, month-end dates, **2001-01-31 → 2026-09-30**, 4,673 rows. Same 15 type/class rows per month as the CSV: Marketable {Bills, Notes, Bonds, TIPS, Floating Rate Notes, Federal Financing Bank}, Nonmarketable {Domestic, Foreign, Government Account, Other, SLGS, Savings}, Total Marketable, Total Nonmarketable, Total Public Debt Outstanding. Units: **$mn** (native, matches convention). Note: bracket characters in the URL must be percent-encoded (`page%5Bsize%5D`) for curl.

### 3c. Dallas Fed par and market value of U.S. government debt — orphan file → FRED

`ONRRP2023/data/manuals/govdebt.xlsx` (no script reads it): monthly, 1942-01 → 2023-10, $bn, six columns: par value of {gross federal debt, privately held gross federal debt, marketable Treasury debt} and market value of the same three.

On FRED (monthly, $bn, 1942-01 → 2026-08, 1,016 obs): MVGFD027MNFRBDAL (market value, gross), MVPHGFD027MNFRBDAL (market value, privately held), MVMTD027MNFRBDAL (market value, marketable Treasury). The par-value columns are **not** on FRED (tested PVGFD027MNFRBDAL etc., 404); the Dallas Fed page remains the source for par values if needed.

### 3d. SIFMA Treasury outstanding (Reserves_Limits, commented out)

`data/monthly_SIFMA.csv` (Jan 2019 → Feb 2021, Total and Notes, $bn) and `data/annual_SIFMA.csv` (2000 → 2018), hand-extracted from the SIFMA "US Treasury Securities Statistics" workbook (sheets Issuance, Trading Volume, Outstanding, Holders, Yield Curve). Code paths that read them are commented out. Superseded by MSPD via FiscalData (3b).

## 4. Other items in this group

| Series | ID | Units | Range | Pulled in |
|---|---|---|---|---|
| Reserves of depository institutions, total (H.3) | TOTRESNS | $bn, monthly, NSA | 1959-01 → 2026-09 | ReservesTrendCo xls only (unlabelled) |
| 3-month T-bill, secondary market, monthly | TB3MS | percent | 1934-01 → 2026-09 | MPdiag |
| 10-yr constant maturity, monthly | GS10 | percent | 1953-04 → 2026-09 | MPdiag |

TOTRESNS is a monthly average of H.4.1-type reserves with longer history (1959) than the weekly WRESBAL on FRED today (2002). Useful as a core long-history anchor.

## 5. Scope decision (user, 2026-11-02)

**Nominal, not real.** Keep both pieces of nominal GDP:
- `GDP` — nominal GDP, $bn SAAR → ×1000 to $mn, 1947Q1 → present.
- `NGDPPOT` — CBO **nominal** potential GDP incl. projections, $bn SAAR → ×1000 to $mn, 1949Q1 → 2036Q4.

**Ignored (not in the pipeline at all):** real GDP `GDPC1`, real potential `GDPPOT`, core PCE inflation `DPCCRV1Q225SBEA`, unemployment `UNRATE`, CBO noncyclical rate `NROU`.

**Treasury debt: kept.** FRED quarterly FYGFDPUN, FDHBFRBN (plus GFDEBTN, FDHBPIN as candidates), and the MSPD monthly table via FiscalData (3b). Dallas Fed market-value series via FRED if wanted.

**Dropped:** SIFMA extracts (3d), NGDPSAXDCUSQ (= GDP/4), Haver GDP, govdebt.xlsx hand file.

**Monthly yields, kept:** `TB3MS` (3-month T-bill secondary market, discount basis, 1934-01 →) and `GS10` (10-year constant maturity, 1953-04 →); percent → ×100 to bp. Monthly averages, so no business-day join.

**Dropped (MPdiag-only):** NBER recession dummies USREC/USRECQ, SEP longer-run set (FEDTARMDLR etc.), Laubach-Williams and SPF xlsx hand files.
