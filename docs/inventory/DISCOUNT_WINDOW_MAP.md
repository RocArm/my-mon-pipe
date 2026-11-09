# Discount window — pulls in the tree and verified sources

Verified 2026-11-02 (FRED via `fredgraph.csv` and series pages; Board page via curl).

## 1. What the projects pull

Only the **primary credit rate** is pulled anywhere. No project pulls discount-window quantities; they come implicitly through H.4.1 totals.

| Variable | ID | Source | Freq | Range requested | Pulled in |
|---|---|---|---|---|---|
| Discount window primary credit rate | DPCREDIT | FRED (H.15) via tidyquant | daily, percent | 2017-01-01 → (Norm24, scrap script); 2018-01-01 → (SRF, `read_ADMIN.R`, label "Discount") | Normalization24 (1), SRF (1) |

## 2. Rates

| Series | ID | Units | Range on FRED | Calendar | Notes |
|---|---|---|---|---|---|
| Primary credit rate | DPCREDIT | percent → ×100 bp | 2003-01-09 → present (6,211 obs) | **weekdays incl. weekday holidays**, no "." rows, no weekends | Must inner-join to the business-day calendar: e.g. 2024-12-25 and 2025-01-01 are present. Changes only on FOMC/Board action, so holiday rows carry stale values and would survive a naive filter. |
| Discount rate, pre-2003 (change dates only) | DISCOUNT | percent | 1934-02-02 → 2002-11-06 (134 obs) | event dates | Irregular, one row per change; needs forward fill onto the calendar. Regime break 2003-01-09 (penalty-rate primary credit replaces below-market adjustment credit). |
| Discount rate, monthly | MDISCRT | percent | 1950-01 → 2002-12 | monthly | Monthly version of the above. |
| Discount rate, IMF IFS copy | INTDSRUSM193N | percent | 1950-01 → 2021-08 | monthly | Redundant. |

Secondary credit rate = primary + 50 bp since 2003 (no FRED daily series). Seasonal credit rate is a market-based formula, published in H.15 but not as a FRED daily ID that I could confirm without an API key.

**Splice flag:** DISCOUNT/MDISCRT (adjustment credit, set below market) and DPCREDIT (penalty rate above target) are different instruments. Joining them into one "discount rate" series needs the same explicit `source` flag and warning as the indicative repo history.

## 3. Quantities — H.4.1 loan lines (weekly, $mn, FRED; see H41_FRED_MAP lines 15–21)

| Line | Week Average | Wednesday Level | Range |
|---|---|---|---|
| Loans, total | RESPPALDXAWNWW | WLCFLL | 2002-12-18 → present |
| Primary credit | WPC | WLCFLPCL | 2002-12-18 → present |
| Secondary credit | WSC | WLCFLSCL | 2002-12-18 → present |
| Seasonal credit | WSB | WLCFLSECL | 2002-12-18 → present |
| Paycheck Protection Program Liquidity Facility | H41RESPPALDJXAWNWW | H41RESPPALDJNWW | 2002-12-18 → present (nonzero 2020-04 →) |
| Bank Term Funding Program | H41RESPPALDKXAWNWW | H41RESPPALDKNWW | 2002-12-18 → **2026-05-06** (discontinued) |
| Other credit extensions | WOCE | WLCFOCEL | 2002-12-18 → present |
| Term Auction Facility credit | TERMAUC | — | **monthly only** on FRED, $bn, 2007-12 → 2011-04 (41 obs). Weekly TAF line not found under the H.4.1 IDs tested; it lives in the discontinued H.4.1 table and may need the release-table listing (API key) or the Board's H.4.1 historical CSVs. |

None of these are pulled by any project. All are candidates for the core H.4.1 pull since they come from the same release.

## 4. Loan-level data — Board of Governors (Dodd-Frank §1103 disclosure)

Page: `https://www.federalreserve.gov/regreform/discount-window.htm` (live, HTTP 200). Quarterly workbooks, one per quarter, released with an approximately two-year lag:

- `https://www.federalreserve.gov/newsevents/files/dw_data_2010_q3.xls`, `..._2010_q4.xls`
- `https://www.federalreserve.gov/regreform/files/dw_data_YYYY_qN.xls` for 2011 Q1 – 2017 Q4, `.xlsx` from 2018 Q1.
- Latest on 2026-11-02: **2024 Q3** (`dw_data_2024_q3.xlsx`, 339 KB, 3,167 loans).

Layout (sheet `discount window loan data`): title rows 1–3, header row 4, data from row 5. Columns: Loan date, Maturity date, Term, Repayment date, Lending Federal Reserve district, Borrower, Borrower city, Borrower state, Borrower ABA number, Type of credit, Interest rate (percent), Loan amount (**dollars**), Other outstanding loans, Total outstanding loans, then collateral lendable value by asset type (14 columns). Dates are Excel serials. Other sheets: `definitions and notes`, `interest rates`. Units: dollars → ÷1e6 to $mn; rate percent → ×100 bp.

Not pulled by any project. Useful only for a project-specific module (borrower-level stigma / term analysis), not core.

## 5. Scope decision (user, 2026-11-02)

- **Core:** DPCREDIT only (business-day filtered, percent → bp). No discount-window quantities in core.
- **Project-specific / optional:** H.4.1 loan lines (§3), pre-2003 discount rate (flagged splice), TAF monthly, Board loan-level workbooks (§4).
