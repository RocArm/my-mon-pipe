"""Generate config/series_registry.csv from the verified source maps.

Run once (and again whenever scope changes). Every row drives download, unit
conversion and placement. Columns:
  name          descriptive snake_case name used in all outputs
  pipe          core | core_q | aux1 | aux2 | aux3 | aux4 | aux5 | legacy
  source        fred | nyfed_rates | nyfed_rp | nyfed_props | fiscaldata | static
  source_id     FRED ID, API rate type, API endpoint, FiscalData table or file name
  stat          WA | WL (H.4.1 pairs) | "" otherwise
  native_freq   d | w | m | q | op (operation-level)
  source_unit   usd_mn | usd_bn | usd | pct | bp | count | ratio
  target_unit   usd_mn | bp | count | ratio
  multiplier    factor applied at load (source -> target)
  start_expected first observation verified on 2026-10-27 / 2026-11-02
  end_expected  "" (live) or last observation of a discontinued series
  group         H41_T1 | H41_T1A | H41_T5 | H3 | RATES | POLICY | ADMIN | OPS | GDP | DEBT | H8 | TSY | LEGACY
  label         human-readable description
"""
import csv, os

rows = []

def add(name, pipe, source, source_id, stat, freq, su, tu, mult, start, end, group, label):
    rows.append(dict(name=name, pipe=pipe, source=source, source_id=source_id, stat=stat,
                     native_freq=freq, source_unit=su, target_unit=tu, multiplier=mult,
                     start_expected=start, end_expected=end, group=group, label=label))

H41_START = "2002-12-18"

def h41(name, wa, wl, pipe, label, group="H41_T1", end_wa="", end_wl=""):
    if wa:
        add(name, pipe, "fred", wa, "WA", "w", "usd_mn", "usd_mn", 1, H41_START, end_wa, group, label + " (week average)")
    if wl:
        add(name, pipe, "fred", wl, "WL", "w", "usd_mn", "usd_mn", 1, H41_START, end_wl, group, label + " (Wednesday level)")

# ---------------------------------------------------------------- core H.4.1 (16 WA+WL pairs + WALCL = 17 series)
h41("securities_held_outright", "WSECOUT", "WSHOSHO", "core", "Securities held outright")
h41("treasuries_held", "WSHOTSA", "WSHOTSL", "core", "U.S. Treasury securities held outright")
h41("bills_held", "WSHOBA", "WSHOBL", "core", "Treasury bills held outright")
h41("notes_bonds_nominal", "WSHONBNA", "WSHONBNL", "core", "Treasury notes and bonds, nominal")
h41("mbs_held", "WMBSEC", "WSHOMCB", "core", "Mortgage-backed securities held outright")
h41("repos", "WREPO", "WORAL", "core", "Repurchase agreements")
h41("loans_total", "RESPPALDXAWNWW", "WLCFLL", "core", "Loans, total")
h41("factors_supplying_total", "WTFSRFA", "WTFSRFL", "core", "Total factors supplying reserve funds")
h41("currency_in_circulation", "WCURCIR", "WCICL", "core", "Currency in circulation")
h41("rrp_total", "WLRRAA", "WLRRAL", "core", "Reverse repurchase agreements, total")
h41("rrp_foreign_official", "WREPOFOR", "WLRRAFOIAL", "core", "Reverse repos: foreign official and international accounts")
h41("on_rrp_others", "WREPODEL", "WLRRAOL", "core", "Reverse repos: others (ON RRP facility)")
h41("tga", "WTREGEN", "WDTGAL", "core", "U.S. Treasury General Account")
h41("other_deposits", "WOTHLB", "WLODL", "core", "Deposits with F.R. Banks: other")
h41("factors_absorbing_ex_reserves", "WTFORBAFA", "WTFORBAFL", "core", "Total factors, other than reserve balances, absorbing reserve funds")
h41("reserve_balances", "WRESBAL", "WRBWFRBL", "core", "Reserve balances with Federal Reserve Banks")
add("total_assets_fed", "core", "fred", "WALCL", "WL", "w", "usd_mn", "usd_mn", 1, H41_START, "", "H41_T5", "Total assets, consolidated statement (Wednesday level)")

# ---------------------------------------------------------------- core rates (FRED, daily -> WL/WA in core)
add("effr", "core", "fred", "EFFR", "", "d", "pct", "bp", 100, "2000-07-03", "", "RATES", "Effective federal funds rate")
add("obfr", "core", "fred", "OBFR", "", "d", "pct", "bp", 100, "2016-03-01", "", "RATES", "Overnight bank funding rate")
add("sofr", "core", "fred", "SOFR", "", "d", "pct", "bp", 100, "2018-04-03", "", "RATES", "Secured overnight financing rate (FRED copy starts one day after the NY Fed; absent on SIFMA closures such as Good Friday, which are fed funds business days)")
add("target_single", "core", "fred", "DFEDTAR", "", "d", "pct", "bp", 100, "1982-09-27", "2008-12-15", "POLICY", "Federal funds target rate, single target (pulled from 2000-07-03)")
add("target_upper", "core", "fred", "DFEDTARU", "", "d", "pct", "bp", 100, "2008-12-16", "", "POLICY", "Federal funds target range, upper limit")
add("target_lower", "core", "fred", "DFEDTARL", "", "d", "pct", "bp", 100, "2008-12-16", "", "POLICY", "Federal funds target range, lower limit")
add("ioer", "core", "fred", "IOER", "", "d", "pct", "bp", 100, "2008-10-09", "2021-07-28", "ADMIN", "Interest on excess reserves")
add("iorr", "core", "fred", "IORR", "", "d", "pct", "bp", 100, "2008-10-09", "2021-07-28", "ADMIN", "Interest on required reserves")
add("iorb", "core", "fred", "IORB", "", "d", "pct", "bp", 100, "2021-07-29", "", "ADMIN", "Interest on reserve balances")
add("on_rrp_rate", "core", "fred", "RRPONTSYAWARD", "", "d", "pct", "bp", 100, "2013-09-23", "", "ADMIN", "ON RRP award rate (rate of accepted propositions: FRED leaves it blank on business days with zero take-up, so it is not a gap-free offering rate)")
add("primary_credit_rate", "core", "fred", "DPCREDIT", "", "d", "pct", "bp", 100, "2003-01-09", "", "ADMIN", "Discount window primary credit rate (weekday holidays present on FRED; calendar join drops them)")
add("on_rrp_overnight_tsy", "core", "fred", "RRPONTSYD", "", "d", "usd_bn", "usd_mn", 1000, "2003-02-07", "", "OPS", "Overnight reverse repo, Treasury collateral, amount accepted (overnight ops only; H.4.1 stock includes term)")
add("repo_overnight_tsy", "core", "fred", "RPONTSYD", "", "d", "usd_bn", "usd_mn", 1000, "2000-01-03", "", "OPS", "Overnight repo, Treasury collateral, amount accepted (overnight ops only)")

# ---------------------------------------------------------------- core quarterly
add("ngdp", "core_q", "fred", "GDP", "", "q", "usd_bn", "usd_mn", 1000, "1947-01-01", "", "GDP", "Nominal GDP, SAAR (pulled in full; aligned weekly by align_quarterly)")
add("ngdp_potential", "core_q", "fred", "NGDPPOT", "", "q", "usd_bn", "usd_mn", 1000, "1949-01-01", "", "GDP", "CBO nominal potential GDP, SAAR, incl. projections to 2036Q4")

# ---------------------------------------------------------------- aux1 distributions (NY Fed API)
for r, start in [("effr", "2000-07-03"), ("obfr", "2016-03-01"), ("sofr", "2018-04-02"), ("bgcr", "2018-04-02"), ("tgcr", "2018-04-02")]:
    sec = "secured" if r in ("sofr", "bgcr", "tgcr") else "unsecured"
    add(f"dist_{r}", "aux1", "nyfed_rates", f"rates/{sec}/{r}/search.csv", "", "d", "pct", "bp", 100, start, "", "RATES",
        f"{r.upper()} published rate, percentiles (bp), volume (usd_bn -> usd_mn x1000), intraday range, target range, revision flag")

# ---------------------------------------------------------------- aux2 remaining H.4.1 Table 1
h41("reserve_bank_credit", "WRESCRT", "WOFSRBRBC", "aux2", "Reserve Bank credit")
h41("notes_bonds_tips", "WSHONBIIA", "WSHONBIIL", "aux2", "Treasury notes and bonds, inflation-indexed")
h41("inflation_compensation", "WSHOICA", "WSHOICL", "aux2", "Inflation compensation on TIPS")
h41("agency_debt_held", "WFEDSEC", "WSHOFADSL", "aux2", "Federal agency debt securities held outright")
h41("unamortized_premiums", "RESPPALSPXAWNWW", "WUPSHO", "aux2", "Unamortized premiums on securities held outright")
h41("unamortized_discounts", "RESPPALSDXAWNWW", "WUDSHO", "aux2", "Unamortized discounts on securities held outright")
h41("repos_foreign_official", "H41RESPPALGTRFXAWNWW", "H41RESPPALGTRFNWW", "aux2", "Repurchase agreements: foreign official")
h41("repos_others", "H41RESPPALGTROXAWNWW", "H41RESPPALGTRONWW", "aux2", "Repurchase agreements: others")
h41("primary_credit", "WPC", "WLCFLPCL", "aux2", "Loans: primary credit")
h41("secondary_credit", "WSC", "WLCFLSCL", "aux2", "Loans: secondary credit")
h41("seasonal_credit", "WSB", "WLCFLSECL", "aux2", "Loans: seasonal credit")
h41("ppplf", "H41RESPPALDJXAWNWW", "H41RESPPALDJNWW", "aux2", "Loans: Paycheck Protection Program Liquidity Facility")
h41("btfp", "H41RESPPALDKXAWNWW", "H41RESPPALDKNWW", "aux2", "Loans: Bank Term Funding Program", end_wa="2026-05-06", end_wl="2026-05-06")
h41("other_credit_extensions", "WOCE", "WLCFOCEL", "aux2", "Other credit extensions")
h41("ms_facilities", "H41RESPPAAEXAWNWW", "H41RESPPAAENWW", "aux2", "Net portfolio holdings of MS Facilities LLC")
h41("mlf", "H41RESPPAADHXAWNWW", "H41RESPPAADHNWW", "aux2", "Net portfolio holdings of Municipal Liquidity Facility LLC", end_wa="2025-02-26", end_wl="2025-02-26")
h41("talf2", "H41RESPPAATAL2HXAWNWW", "H41RESPPAATAL2HNWW", "aux2", "Net portfolio holdings of TALF II LLC", end_wa="2025-02-26", end_wl="2025-02-26")
h41("float", "WOFSRBFA", "WOFSRBFL", "aux2", "Float")
h41("cb_liquidity_swaps", "WCBLSA", "SWPT", "aux2", "Central bank liquidity swaps")
h41("other_fed_assets", "WOTHAST", "WOFRAL", "aux2", "Other Federal Reserve assets")
h41("foreign_currency_assets", "RESPPAOFXAWNWW", "WFCDA", "aux2", "Foreign currency denominated assets")
h41("gold_stock", "WOFSRBGSA", "WOFSRBGSL", "aux2", "Gold stock")
h41("sdr_certificates", "WOSDRA", "WOSDRL", "aux2", "Special drawing rights certificate account")
h41("treasury_currency", "WTCOA", "WTCOL", "aux2", "Treasury currency outstanding")
h41("treasury_cash", "WOFDRBTHA", "WOFDRBTHL", "aux2", "Treasury cash holdings")
h41("deposits_other_than_reserves", "WOFDRBORBA", "WOFDRBORBL", "aux2", "Deposits with F.R. Banks, other than reserve balances")
h41("term_deposits", "WLTDHDIA", "TERMT", "aux2", "Term deposits held by depository institutions")
h41("foreign_official_deposits", "WDFOA", "WDFOL", "aux2", "Deposits: foreign official")
h41("treasury_credit_facility_contrib", "H41RESH4EXAWNWW", "H41RESH4ENWW", "aux2", "Treasury contributions to credit facilities")
h41("other_liabilities_capital", "WOTHLIAB", "WOLCL", "aux2", "Other liabilities and capital")
# Table 1A memoranda
h41("custody_foreign_total", "WSEFINT1", "WSEFINTL1", "aux2", "Securities held in custody for foreign official and international accounts", group="H41_T1A")
h41("custody_foreign_treasuries", "WMTSEC1", "WMTSECL1", "aux2", "Custody: marketable U.S. Treasury securities", group="H41_T1A")
h41("custody_foreign_agency", "WFASEC1", "WFASECL1", "aux2", "Custody: federal agency debt and MBS", group="H41_T1A")
h41("custody_foreign_other", "WSEFINO", "WSEFINOL", "aux2", "Custody: other securities", group="H41_T1A")
h41("securities_lent", "WSDEAL", "WSDEALL", "aux2", "Securities lent to dealers", group="H41_T1A")
h41("securities_lent_overnight", "WSDONT", "WSDONTL", "aux2", "Securities lent: overnight facility", group="H41_T1A")
h41("securities_lent_treasuries", "WSDTREAA", "WSDTREAL", "aux2", "Securities lent: U.S. Treasury securities", group="H41_T1A")
h41("securities_lent_agency", "WSDFDSA", "WSDFDSL", "aux2", "Securities lent: federal agency debt", group="H41_T1A")
# Table 5 (Wednesday level only; items not already covered by Table 1 IDs)
for name, sid, label, end in [
    ("gold_certificate", "WGCAL", "Gold certificate account", ""),
    ("coin", "WACL", "Coin", ""),
    ("securities_premiums_repos_loans", "WSRLL", "Securities, unamortized premiums and discounts, repos, and loans", ""),
    ("cpff2", "H41RESPPAAC2HNWW", "Net portfolio holdings of CPFF II LLC", "2022-07-20"),
    ("corporate_credit_facilities", "H41RESPPAABNWW", "Net portfolio holdings of Corporate Credit Facilities LLC", "2022-12-21"),
    ("items_in_process_of_collection", "WPCLC", "Items in process of collection", ""),
    ("bank_premises", "WABPL", "Bank premises", ""),
    ("other_assets_t5", "WAOAL", "Other assets", ""),
    ("total_liabilities", "WLTLECL", "Total liabilities", ""),
    ("frn_outstanding_net", "WLFN", "Federal Reserve notes, net of F.R. Bank holdings", ""),
    ("deposits_total", "WLDLCL", "Deposits, total", ""),
    ("other_deposits_held_by_dis", "WLODLL", "Other deposits held by depository institutions (Table 5 line; close to but not equal to reserve balances WRBWFRBL before 2013, differences of up to 23 $bn in 2002-2012)", ""),
    ("deferred_availability_cash_items", "WLDACLC", "Deferred availability cash items", ""),
    ("other_liabilities_accrued_dividends", "WLAD", "Other liabilities and accrued dividends", ""),
    ("capital_total", "WCTCL", "Total capital", ""),
    ("capital_paid_in", "WCPIL", "Capital paid in", ""),
    ("capital_surplus", "WCSL", "Surplus", ""),
    ("capital_other", "WCPCA", "Other capital accounts", ""),
]:
    add(name, "aux2", "fred", sid, "WL", "w", "usd_mn", "usd_mn", 1, H41_START, end, "H41_T5", label + " (Wednesday level)")
# H.3 reserve balances: NOT pulled (decision D19, 2026-11-09): H.3 was discontinued in Sept 2020 and its
# reserve-balance construct differs from H.4.1 (median gap ~1.4 %), so it has no place in the pipeline.

# ---------------------------------------------------------------- aux3 Treasury debt + H.8
QDEBT = " (end-of-quarter stock dated by FRED on the quarter START: the 2025-04-01 row is the 2025-06-30 level)"
add("debt_held_by_public", "aux3", "fred", "FYGFDPUN", "", "q", "usd_mn", "usd_mn", 1, "1970-01-01", "", "DEBT", "Federal debt held by the public" + QDEBT)
add("debt_held_by_frb", "aux3", "fred", "FDHBFRBN", "", "q", "usd_bn", "usd_mn", 1000, "1970-01-01", "", "DEBT", "Federal debt held by Federal Reserve Banks" + QDEBT)
add("debt_held_by_private", "aux3", "fred", "FDHBPIN", "", "q", "usd_bn", "usd_mn", 1000, "1970-01-01", "", "DEBT", "Federal debt held by private investors" + QDEBT)
add("debt_total_public", "aux3", "fred", "GFDEBTN", "", "q", "usd_mn", "usd_mn", 1, "1966-01-01", "", "DEBT", "Federal debt: total public debt" + QDEBT)
add("mspd_table1", "aux3", "fiscaldata", "v1/debt/mspd/mspd_table_1", "", "m", "usd_mn", "usd_mn", 1, "2001-01-31", "", "DEBT", "Monthly Statement of the Public Debt, summary by security type/class: held by public, intragovernmental, total")

def h8(name, sa, nsa, label, start="1973-01-03", pipe="aux3"):
    if sa:
        add(name + "_sa", pipe, "fred", sa, "", "w", "usd_bn", "usd_mn", 1000, start, "", "H8", label + ", SA")
    if nsa:
        add(name + "_nsa", pipe, "fred", nsa, "", "w", "usd_bn", "usd_mn", 1000, start, "", "H8", label + ", NSA")

h8("h8_total_assets", "TLAACBW027SBOG", "TLAACBW027NBOG", "Total assets, all commercial banks")
h8("h8_deposits", "DPSACBW027SBOG", "DPSACBW027NBOG", "Deposits, all commercial banks")
h8("h8_bank_credit", "TOTBKCR", "TOTBKCRNSA", "Bank credit, all commercial banks")
h8("h8_loans_leases", "TOTLL", "TOTLLNSA", "Loans and leases in bank credit, all commercial banks")
h8("h8_treasury_agency_sec", "TASACBW027SBOG", "TASACBW027NBOG", "Treasury and agency securities, all commercial banks")
h8("h8_cash_assets", "CASACBW027SBOG", "CASACBW027NBOG", "Cash assets, all commercial banks")
for grp, code, lbl, start in [("fbo", "FRI", "foreign-related institutions", "1973-01-03"),
                              ("dom", "DCB", "domestically chartered commercial banks", "1973-01-03"),
                              ("large", "LCB", "large domestically chartered commercial banks", "1985-04-03"),
                              ("small", "SCB", "small domestically chartered commercial banks", "1985-04-03")]:
    for pre, lab in [("TLA", "Total assets"), ("TAS", "Treasury and agency securities"), ("LLB", "Loans and leases in bank credit"),
                     ("CAS", "Cash assets"), ("DPS", "Deposits")]:
        st = "1973-01-03" if (grp == "small" and pre == "DPS") else start
        add(f"h8_{grp}_{pre.lower()}_sa", "aux3", "fred", f"{pre}{code}W027SBOG", "", "w", "usd_bn", "usd_mn", 1000, st, "", "H8", f"{lab}, {lbl}, SA")
for grp, code, start in [("all", "CBA", "2010-01-06"), ("fbo", "FRA", "2010-01-06"), ("dom", "DMA", "2010-01-06"), ("large", "LGA", "2010-01-06"), ("small", "SMA", "2010-01-06")]:
    add(f"h8_{grp}_fed_funds_sold_rrp", "aux3", "fred", f"H8B3092N{code}", "", "w", "usd_mn", "usd_mn", 1, start, "", "H8", f"Fed funds sold and reverse RPs (memo), {grp}, NSA")
for grp, code, start in [("all", "CBA", "1973-01-03"), ("fbo", "FRA", "1973-01-03"), ("dom", "DMA", "1973-01-03"), ("large", "LGA", "1985-04-03"), ("small", "SMA", "1985-04-03")]:
    add(f"h8_{grp}_borrowings", "aux3", "fred", f"H8B3094N{code}", "", "w", "usd_mn", "usd_mn", 1, start, "", "H8", f"Borrowings (memo), {grp}, NSA")
add("h8_deposits_m_sa", "aux3", "fred", "DPSACBM027SBOG", "", "m", "usd_bn", "usd_mn", 1000, "1973-01-01", "", "H8", "Deposits, all commercial banks, monthly, SA")
add("h8_deposits_m_nsa", "aux3", "fred", "DPSACBM027NBOG", "", "m", "usd_bn", "usd_mn", 1000, "1973-01-01", "", "H8", "Deposits, all commercial banks, monthly, NSA")
add("h8_total_assets_m_sa", "aux3", "fred", "TLAACBM027SBOG", "", "m", "usd_bn", "usd_mn", 1000, "1973-01-01", "", "H8", "Total assets, all commercial banks, monthly, SA")
add("h8_total_assets_m_nsa", "aux3", "fred", "TLAACBM027NBOG", "", "m", "usd_bn", "usd_mn", 1000, "1973-01-01", "", "H8", "Total assets, all commercial banks, monthly, NSA")
add("h8_bank_credit_m_sa", "aux3", "fred", "LOANINV", "", "m", "usd_bn", "usd_mn", 1000, "1947-01-01", "", "H8", "Bank credit, all commercial banks, monthly, SA")
add("h8_loans_leases_m_sa", "aux3", "fred", "LOANS", "", "m", "usd_bn", "usd_mn", 1000, "1947-01-01", "", "H8", "Loans and leases in bank credit, all commercial banks, monthly, SA")

# ---------------------------------------------------------------- aux4 Treasury rates
for sid, name, label, start in [("DGS1", "tsy_1y", "1-year constant maturity", "1962-01-02"), ("DGS2", "tsy_2y", "2-year constant maturity", "1976-06-01"),
                                ("DGS5", "tsy_5y", "5-year constant maturity", "1962-01-02"), ("DGS10", "tsy_10y", "10-year constant maturity", "1962-01-02"),
                                ("DFII10", "tips_10y", "10-year TIPS constant maturity", "2003-01-02"),
                                ("DTB4WK", "bill_4w", "4-week bill, secondary market, discount basis", "2001-07-31"),
                                ("DTB3", "bill_3m", "3-month bill, secondary market, discount basis", "1954-01-04"),
                                ("DTB6", "bill_6m", "6-month bill, secondary market, discount basis", "1958-12-09")]:
    add(name, "aux4", "fred", sid, "", "d", "pct", "bp", 100, start, "", "TSY", label + " (daily)")
add("bill_3m_m", "aux4", "fred", "TB3MS", "", "m", "pct", "bp", 100, "1934-01-01", "", "TSY", "3-month bill, secondary market, monthly average")
add("tsy_10y_m", "aux4", "fred", "GS10", "", "m", "pct", "bp", 100, "1953-04-01", "", "TSY", "10-year constant maturity, monthly average")

# ---------------------------------------------------------------- aux5 operations (NY Fed API)
add("ops_results", "aux5", "nyfed_rp", "rp/results/search.csv", "", "op", "usd_bn", "usd_mn", 1000, "2000-07-07", "", "OPS", "Repo and reverse repo operation results, operation level; rates pct -> bp")
add("ops_rrp_by_counterparty", "aux5", "nyfed_props", "rp/reverserepo/propositions/search.csv", "", "op", "usd_bn", "usd_mn", 1000, "2013-09-23", "", "OPS", "ON RRP amounts accepted by counterparty type (Bank, GSE, MMF, PD)")

# ---------------------------------------------------------------- legacy (static NY Fed files)
add("ind_repo_rates", "legacy", "static", "indicative_repo_2014_2018.xlsx", "", "d", "bp", "bp", 1, "2014-08-22", "2018-03-29", "LEGACY", "Indicative TGCR/BGCR/SOFR volume-weighted median rates (sheet VWM Rates, already bp)")
add("ind_repo_volumes", "legacy", "static", "indicative_repo_2014_2018.xlsx", "", "d", "usd_bn", "usd_mn", 1000, "2014-08-22", "2018-03-29", "LEGACY", "Indicative TGCR/BGCR/SOFR volumes (sheet Volumes)")
add("ind_ff_brokered", "legacy", "static", "ff_volumes_2006_2016.xlsx", "", "d", "pct", "bp", 100, "2006-10-02", "2016-02-29", "LEGACY", "Brokered fed funds percentiles (pct -> bp) and volume (usd_bn -> usd_mn)")
add("ind_sofr_averages", "legacy", "static", "indicative_sofr_avg_2018_2020.xlsx", "", "d", "pct", "bp", 100, "2018-04-02", "2020-02-28", "LEGACY", "Indicative SOFR 30/90/180-day averages (pct -> bp) and index (ratio, x1)")

# ---------------------------------------------------------------- write
out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "config", "series_registry.csv")
with open(out, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader(); w.writerows(rows)

# ---------------------------------------------------------------- data dictionary (markdown, same source of truth)
PIPE_TITLES = {
    "core": "core_daily + core_weekly (from 2002-12-18; native_freq d rows are written daily to core_daily and as WL/WA to core_weekly; native_freq w rows to core_weekly only)",
    "core_q": "core_quarterly (as published; align with align_quarterly())",
    "aux1": "aux1_distributions (NY Fed API, daily business days; stats rate/p1/p25/p75/p99/volume/target_from/target_to/intraday_low/intraday_high/std_dev/revised)",
    "aux2": "aux2_h41_rest (weekly H.4.1 Tables 1/1A/5 remainder)",
    "aux3": "aux3_debt_h8 (quarterly debt aggregates; monthly MSPD as mspd_* with stats public/intragov/total; weekly and monthly H.8)",
    "aux4": "aux4_treasury_rates (daily business days; two monthly averages)",
    "aux5": "aux5_operations / aux5_rrp_by_counterparty (wide, operation level)",
    "legacy": "legacy_indicative (ind_ prefix; warning on load)",
}
OUT_NAMES = {  # registry name -> series name(s) actually written, where they differ
    "mspd_table1": "mspd_<type>_<class> (21 series)",
    "ops_results": "(wide table aux5_operations)",
    "ops_rrp_by_counterparty": "(wide table aux5_rrp_by_counterparty)",
    "ind_repo_rates": "ind_tgcr, ind_bgcr, ind_sofr (stat rate)",
    "ind_repo_volumes": "ind_tgcr, ind_bgcr, ind_sofr (stat volume)",
    "ind_ff_brokered": "ind_effr_brokered (stats p1 p25 p50 p75 p99 volume)",
    "ind_sofr_averages": "ind_sofr_averages (stats avg30 avg90 avg180 index)",
}
md = ["# Data dictionary", "",
      "Generated by `scripts/build_registry.py` from `config/series_registry.csv`; do not edit by hand.",
      "Units: `usd_mn` = millions of US dollars, `bp` = basis points. `multiplier` is applied once at load to the source unit.",
      "`stat` for H.4.1 rows: WA = week average (7-day, as published), WL = Wednesday level. Daily series in core get both",
      "WL (value on the Wednesday-level date) and WA (7-calendar-day mean Thu..Wed, non-business days carrying the last",
      "business-day value, bounded by the series' last observation) at build time. Daily series on FRED may be blank on",
      "calendar business days (SOFR and Treasury yields on SIFMA closures, the ON RRP award rate on zero-take-up days);",
      "such days are absent from the daily tables, and the WA carries the previous value across them.", ""]
for pipe in ["core", "core_q", "aux1", "aux2", "aux3", "aux4", "aux5", "legacy"]:
    sub = [r for r in rows if r["pipe"] == pipe]
    md += [f"## {PIPE_TITLES[pipe]}", "", f"{len(sub)} registry rows.", "",
           "| series | stat | label | source | source_id | native | source unit → target (×) | start | end |", "|---|---|---|---|---|---|---|---|---|"]
    for r in sub:
        nm = OUT_NAMES.get(r["name"], r["name"])
        md.append(f"| `{nm}` | {r['stat']} | {r['label']} | {r['source']} | `{r['source_id']}` | {r['native_freq']} | {r['source_unit']} → {r['target_unit']} (×{r['multiplier']}) | {r['start_expected']} | {r['end_expected']} |")
    md.append("")
md += ["## Composites built in core (not registry rows)", "",
       "| series | definition | source column |", "|---|---|---|",
       "| `target_top` | DFEDTARU from 2008-12-16, else DFEDTAR (single target) | raw ID(s) used in the week, e.g. `DFEDTAR+DFEDTARU` in the transition week |",
       "| `target_bottom` | DFEDTARL from 2008-12-16, else DFEDTAR, so the range has zero width before 2008-12-16 | as above |",
       "| `ior` | IORB from 2021-07-29, else IOER | `IOER` or `IORB` |", ""]
docs_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs")
os.makedirs(docs_dir, exist_ok=True)
with open(os.path.join(docs_dir, "DATA_DICTIONARY.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(md) + "\n")

names = [r["name"] + "/" + r["stat"] for r in rows]
assert len(names) == len(set(names)), "duplicate name/stat"
ids = [(r["source"], r["source_id"], r["stat"]) for r in rows if r["source"] != "static"]
assert len(ids) == len(set(ids)), "duplicate source_id"  # static files legitimately feed several series
from collections import Counter
print("rows:", len(rows)); print(Counter(r["pipe"] for r in rows)); print(Counter(r["source"] for r in rows))
