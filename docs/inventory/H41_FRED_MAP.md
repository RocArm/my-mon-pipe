# H.4.1 on FRED — complete series map (Tables 1, 1A, 5)

Source: FRED release tables for H.4.1 (rid=20), read 2026-10-27:
Table 1 parent eid=1193942 → Week Average eid=1193993, Wednesday Level eid=1193943; Table 1A parent eid=840826 → WA eid=840838, WL eid=840827; Table 5 eid=1194154 (Wednesday Level only).
Every ID below was fetched from `fred.stlouisfed.org/graph/fredgraph.csv?id=` on 2026-10-27. Unless noted: **Millions of U.S. Dollars, NSA, weekly, first obs 2002-12-18, last obs 2026-10-21, 1,245 obs.**
Discontinued series (last obs earlier) are marked. Line order and nesting follow the release table.

Flag: on 2025-02-27 FRED served WRESBAL, WCURCIR, WTREGEN, WSECOUT in **billions** with history back to 1984/1986/1989 (evidence: `BS/Bridge2025/data/raw/fred_data.Rdata`). Today all four are millions from 2002-12-18. Pre-2002 history is only in that snapshot (or ALFRED vintages).

## Table 1. Factors Affecting Reserve Balances of Depository Institutions

| # | Line | Week Average | Wednesday Level | Pulled in tree |
|---|---|---|---|---|
| 1 | Reserve Bank credit | WRESCRT | WOFSRBRBC | — |
| 2 | ↳ Securities held outright | WSECOUT | WSHOSHO | WA: Norm24, Bridge2025, TrendReserves. WL: Reserves_Limits |
| 3 | ↳↳ U.S. Treasury securities | WSHOTSA | WSHOTSL | WA: SRF, ONRRP2023. WL: SRF |
| 4 | ↳↳↳ Bills | WSHOBA | WSHOBL | WA: SRF, ONRRP2023. WL: SRF |
| 5 | ↳↳↳ Notes and bonds, nominal | WSHONBNA | WSHONBNL | — |
| 6 | ↳↳↳ Notes and bonds, inflation-indexed | WSHONBIIA | WSHONBIIL | — |
| 7 | ↳↳↳ Inflation compensation | WSHOICA | WSHOICL | — |
| 8 | ↳↳ Federal agency debt securities | WFEDSEC | WSHOFADSL (= FEDDT, identical values) | SRF (WFEDSEC, FEDDT) |
| 9 | ↳↳ Mortgage-backed securities | WMBSEC | WSHOMCB | WA: SRF, ONRRP2023. WL: SRF |
| 10 | ↳↳ Unamortized premiums on securities held outright | RESPPALSPXAWNWW | WUPSHO | — |
| 11 | ↳↳ Unamortized discounts on securities held outright | RESPPALSDXAWNWW | WUDSHO | — |
| 12 | ↳ Repurchase agreements | WREPO | WORAL | WL: Reserves_Limits |
| 13 | ↳↳ Foreign official | H41RESPPALGTRFXAWNWW | H41RESPPALGTRFNWW | — |
| 14 | ↳↳ Others | H41RESPPALGTROXAWNWW | H41RESPPALGTRONWW | — |
| 15 | ↳ Loans | RESPPALDXAWNWW | WLCFLL | — |
| 16 | ↳↳ Primary credit | WPC | WLCFLPCL | — |
| 17 | ↳↳ Secondary credit | WSC | WLCFLSCL | — |
| 18 | ↳↳ Seasonal credit | WSB | WLCFLSECL | — |
| 19 | ↳↳ Paycheck Protection Program Liquidity Facility | H41RESPPALDJXAWNWW | H41RESPPALDJNWW | — |
| 20 | ↳↳ Bank Term Funding Program | H41RESPPALDKXAWNWW (ends 2026-05-06) | H41RESPPALDKNWW (ends 2026-05-06) | — |
| 21 | ↳ Other credit extensions | WOCE | WLCFOCEL | — |
| 22 | ↳ Net portfolio holdings of MS Facilities LLC | H41RESPPAAEXAWNWW | H41RESPPAAENWW | — |
| 23 | ↳ Net portfolio holdings of Municipal Liquidity Facility LLC | H41RESPPAADHXAWNWW (ends 2025-02-26) | H41RESPPAADHNWW (ends 2025-02-26) | — |
| 24 | ↳ Net portfolio holdings of TALF II LLC | H41RESPPAATAL2HXAWNWW (ends 2025-02-26) | H41RESPPAATAL2HNWW (ends 2025-02-26) | — |
| 25 | ↳ Float | WOFSRBFA | WOFSRBFL | — |
| 26 | ↳ Central bank liquidity swaps | WCBLSA | SWPT | — |
| 27 | ↳ Other Federal Reserve assets | WOTHAST | WOFRAL | — |
| 28 | ↳↳ Foreign currency denominated assets | RESPPAOFXAWNWW | WFCDA | — |
| 29 | Gold stock | WOFSRBGSA | WOFSRBGSL | — |
| 30 | Special drawing rights certificate account | WOSDRA | WOSDRL | — |
| 31 | Treasury currency outstanding | WTCOA | WTCOL | — |
| 32 | **Total factors supplying reserve funds** | WTFSRFA | WTFSRFL | WA: Norm24, Bridge2025, SRF, ONRRP2023. WL: SRF |
| 33 | Currency in circulation | WCURCIR | WCICL | WA: Norm24, Bridge2025, ReservesVAR |
| 34 | Reverse repurchase agreements | WLRRAA | WLRRAL | WL: Reserves_Limits |
| 35 | ↳ Foreign official and international accounts | WREPOFOR | WLRRAFOIAL | WL: ReservesVAR |
| 36 | ↳ Others (ON RRP facility) | WREPODEL | WLRRAOL | WA: Norm24, Bridge2025, SRF, ONRRP2023, Reserves_Limits, TrendReserves. WL: SRF, ReservesVAR |
| 37 | Treasury cash holdings | WOFDRBTHA | WOFDRBTHL | — |
| 38 | Deposits with F.R. Banks, other than reserve balances | WOFDRBORBA | WOFDRBORBL | — |
| 39 | ↳ Term deposits held by depository institutions | WLTDHDIA | TERMT | — |
| 40 | ↳ U.S. Treasury, General Account | WTREGEN | WDTGAL | WA: Bridge2025, SRF, ONRRP2023, ReservesVAR. WL: Norm24, Bridge2025, SRF, ONRRP2023, Reserves_Limits |
| 41 | ↳ Foreign official | WDFOA | WDFOL | — |
| 42 | ↳ Other | WOTHLB | WLODL | WL: ReservesVAR |
| 43 | Treasury contributions to credit facilities | H41RESH4EXAWNWW | H41RESH4ENWW | — |
| 44 | Other liabilities and capital | WOTHLIAB | WOLCL | — |
| 45 | **Total factors, other than reserve balances, absorbing reserve funds** | WTFORBAFA | WTFORBAFL | — (Haver FRA in SlowSmooth) |
| 46 | **Reserve balances with Federal Reserve Banks** | WRESBAL | WRBWFRBL | WA: Norm24, Bridge2025, SRF, ONRRP2023, ReservesVAR, TrendReserves. WL: SRF, Reserves_Limits |

Identities checked on 2026-10-21 (WL): 3 = 4+5+6+7; 2 = 3+8+9; 34 = 35+36; 32 = 45+46; 38 = 39+40+41+42 (1,193,302 = 0+945,153+9,476+238,673).

## Table 1A. Memorandum Items

| Line | Week Average | Wednesday Level |
|---|---|---|
| Securities held in custody for foreign official and international accounts | WSEFINT1 | WSEFINTL1 |
| ↳ Marketable U.S. Treasury securities | WMTSEC1 | WMTSECL1 |
| ↳ Federal agency debt and mortgage-backed securities | WFASEC1 | WFASECL1 |
| ↳ Other securities | WSEFINO | WSEFINOL |
| Securities lent to dealers | WSDEAL | WSDEALL |
| ↳ Overnight facility | WSDONT | WSDONTL |
| ↳↳ U.S. Treasury securities | WSDTREAA | WSDTREAL |
| ↳↳ Federal agency debt securities | WSDFDSA | WSDFDSL |

None pulled anywhere in the tree.

## Table 5. Consolidated Statement of Condition (Wednesday Level only)

Assets: WALCL total assets; WGCAL gold certificate; WOSDRL SDR certificate; WACL coin; WSRLL securities+premiums+discounts+repos+loans; WSHOSHO … WSHOMCB as Table 1; WUPSHO, WUDSHO; WORAL repos; WLCFLL loans; H41RESPPAAC2HNWW CPFF II (ends 2022-07-20); H41RESPPAABNWW Corporate Credit Facilities (ends 2022-12-21); H41RESPPAAENWW MS Facilities; H41RESPPAADHNWW MLF (ends 2025-02-26); H41RESPPAATAL2HNWW TALF II (ends 2025-02-26); WPCLC items in process of collection; WABPL bank premises; SWPT swaps; WFCDA foreign currency assets; WAOAL other assets.

Liabilities: WLTLECL total liabilities; WLFN Federal Reserve notes net; WLRRAL reverse repos; WLDLCL deposits; TERMT term deposits; WLODLL other deposits held by depository institutions (close to reserve balances WRBWFRBL only from 2013; differences up to 23 $bn in 2002-2012, corrected 2026-11-09); WDTGAL TGA; WDFOL foreign official; WLODL other; H41RESH4ENWW Treasury contributions; WLDACLC deferred availability cash items; WLAD other liabilities and accrued dividends.

Capital: WCTCL total; WCPIL paid in; WCSL surplus; WCPCA other.

None pulled anywhere in the tree except WLRRAL, WDTGAL, WLODL (via Table 1 IDs).
