# H.4.1 on FRED — verified level / average pairs

Verified 2026-10-27 against each FRED series page (units, frequency) and the keyless CSV endpoint `fred.stlouisfed.org/graph/fredgraph.csv?id=...` (first/last observation).

**Every series below, today: Millions of U.S. Dollars, NSA, weekly, first obs 2002-12-18, last obs 2026-10-21, 1,245 obs.** Week Average = 7 days ending Wednesday. Wednesday Level = close of business Wednesday.

## Unit / history change on FRED (relevant to "longest range")

The Bridge2025 snapshot `BS/Bridge2025/data/raw/fred_data.Rdata` (pulled 2025-02-27 via the FRED REST API, metadata stored) shows that at that date FRED served four week-average series in **billions** with pre-2002 history sourced from the Annual Statistical Digest / Board tables:

| ID | Units on 2025-02-27 | First obs then | Units today | First obs today |
|---|---|---|---|---|
| WRESBAL | Billions of U.S. Dollars | 1984-01-04 | Millions | 2002-12-18 |
| WCURCIR | Billions of U.S. Dollars | 1984-01-04 | Millions | 2002-12-18 |
| WTREGEN | Billions of U.S. Dollars | 1986-01-08 | Millions | 2002-12-18 |
| WSECOUT | Billions of U.S. Dollars | 1989-03-22 | Millions | 2002-12-18 |
| WREPODEL, WTFSRFA, WDTGAL | Millions | 2002-12-18 | Millions | 2002-12-18 |

Values at overlapping dates agree exactly after ×1000 (e.g. WRESBAL 2025-02-26: 3,327.249 bn then, 3,327,249 mn now). Consequences:

- This is why the old code divides some series by 1000 and not others; any pipeline must not copy those per-series divisors.
- The 1984–2002 history for those four series is no longer on FRED under these IDs. It survives on disk in the Bridge2025 snapshot (and in `older_files/fred_2025-03-05.Rdata`). If the longest range matters, options are: splice from that snapshot (×1000), or pull the pre-2025 vintage from ALFRED. Wednesday-level series never had pre-2002 history on FRED.
- Normalization24 / SRF / ONRRP2023 snapshots on disk (2024–Feb 2026) also carry WRESBAL in billions; ONRRP2023's Feb-2026 files should be checked before mixing with a fresh pull.

## Assets

| H.4.1 line | Week Average | Wednesday Level | Pulled in tree (call sites) |
|---|---|---|---|
| Total factors supplying reserve funds | WTFSRFA | WTFSRFL | A: Normalization24, Bridge2025, SRF, ONRRP2023 (6). L: SRF (1) |
| Total assets (less eliminations) | — (none on FRED) | WALCL | not pulled |
| Securities held outright, total | WSECOUT | WSHOSHO | A: Normalization24, Bridge2025, TrendReserves (4). L: Reserves_Limits (2) |
| U.S. Treasury securities, total | WSHOTSA | WSHOTSL | A: SRF, ONRRP2023 (2). L: SRF (1) |
| Bills | WSHOBA | WSHOBL | A: SRF, ONRRP2023 (2). L: SRF (1) |
| Notes & bonds, nominal | WSHONBNA | WSHONBNL | not pulled (L commented out in Reserves_Limits) |
| Notes & bonds, inflation-indexed | WSHONBIIA | WSHONBIIL | not pulled |
| Inflation compensation | WSHOICA | WSHOICL | not pulled |
| Federal agency debt securities | WFEDSEC | FEDDT | SRF (1 each) |
| Mortgage-backed securities | WMBSEC | WSHOMCB | A: SRF, ONRRP2023 (2). L: SRF (1) |
| Repurchase agreements (Fed lending repo) | WREPO | WORAL | L: Reserves_Limits (2) |

Identity check on 2026-10-21 (millions): WSHOTSL 4,572,654 = WSHOBL 567,875 + WSHONBNL 3,620,788 + WSHONBIIL 277,656 + WSHOICL 106,336 (sums to 4,572,655; rounding). WSHOSHO 6,470,178 = WSHOTSL + FEDDT 2,347 + WSHOMCB 1,895,177 (= 6,470,178).

## Liabilities / factors absorbing reserves

| H.4.1 line | Week Average | Wednesday Level | Pulled in tree (call sites) |
|---|---|---|---|
| Reserve balances with FRBs | WRESBAL | WRBWFRBL | A: 6 projects (12). L: SRF, Reserves_Limits (3) |
| Currency in circulation | WCURCIR | WCICL | A: Normalization24, Bridge2025, ReservesVAR (3) |
| Treasury General Account | WTREGEN | WDTGAL | A: 4 projects (5). L: 5 projects (7) |
| Reverse repos, total | WLRRAA | WLRRAL | L: Reserves_Limits (2) |
| Reverse repos, others (ON RRP facility) | WREPODEL | WLRRAOL | A: 6 projects (10). L: SRF, ReservesVAR (2) |
| Reverse repos, foreign official & international (foreign repo pool) | WREPOFOR | WLRRAFOIAL | L: ReservesVAR (1) |
| Deposits: other (non-reserve, non-TGA, non-foreign) | — (not identified) | WLODL | L: ReservesVAR (1) |
| Other deposits held by depository institutions (= reserve balances line) | — | WLODLL | not pulled; equals WRBWFRBL |
| Total factors other than reserves absorbing reserve funds | — (not identified) | WTFORBAFL | not pulled; Haver FRA in SlowSmooth |

Identity check 2026-10-21: WLRRAL 334,083 = WLRRAOL 237 + WLRRAFOIAL 333,846 (exact). WTFSRFL 6,805,516 ≈ WRBWFRBL 2,969,522 + WTFORBAFL 3,835,994 (= 6,805,516, exact).

## Haver equivalents (Armenter_SlowSmooth, WEEKLY db, 2019 vintage, fixed ends)

| Haver | FRED pair |
|---|---|
| FRB | WRESBAL / WRBWFRBL |
| FRAC | WCURCIR / WCICL |
| FRA | — / WTFORBAFL |
| FRAR | WLRRAA / WLRRAL |
| FRADT | WTREGEN / WDTGAL |
| FRSBHO | WSECOUT / WSHOSHO |
| FRSBGB | WSHOTSA / WSHOTSL |
| FRSBMB | WMBSEC / WSHOMCB |
| FSOMA, FSUAMBS | NY Fed SOMA totals; ≈ WSECOUT / WMBSEC |

## Ranges requested in code (for reference)

Bridge2025: no start date (full history). TrendReserves: 1960. Reserves_Limits: 2000. ReservesVAR: 2012-10 to 2018-03. Normalization24: 2014 / 2017. SRF: 2018. ONRRP2023: 2020. SlowSmooth (Haver): 2000 / 2014 to 2019-08. All others "to present".
