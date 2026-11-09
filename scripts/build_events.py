"""Build config/events.csv (point events) and config/episodes.csv (intervals) from the
provenance files in config/sources/. Deterministic; re-run after editing the rules below.

Decisions applied (user, 2026-11-09):
  1. Recessions are episodes dated by NBER peak/trough months, not point rows from the FRED dummy.
  2. Conference calls whose statement came the next morning are dated on the statement day; meeting day in memo.
  3. Month-only sources (runoff start Oct 2017, end Aug 2019) use the first of the month, memo says so.
  4. policy_rate_regime rows (cycle turning points, IOER technical adjustments, intermeeting cuts) are NOT kept:
     all are derivable from core_daily target/IOR series; the agent's extra balance-sheet rows stay.
  5. Facility terminations inferred from a final extension release stay, confidence medium, memo says inferred.
Plus: the four hand-typed Normalization24 dates are merged (memo appended) or added with source "hand".
"""
import csv, os
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "config", "sources")

def read(name):
    with open(os.path.join(SRC, name), encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

cand = read("events_candidate_2026-11-09.csv")
rows = []  # dicts: date, event_type, memo, source, confidence

# ---- 1. drop recession point rows (episodes carry them) -------------------------------------------------
for r in cand:
    if r["event_type"] in ("recession", "policy_rate_regime"):
        continue   # recessions -> episodes; policy_rate_regime dropped (user, 2026-11-09): derivable from core rates
    rows.append(dict(r))

# ---- 2. conference calls dated on the statement day ---------------------------------------------------------
SHIFT = {("2008-01-21", "fomc_meeting"): "2008-01-22",
         ("2008-10-07", "fomc_meeting"): "2008-10-08",
         ("2020-03-02", "fomc_meeting"): "2020-03-03"}
for r in rows:
    k = (r["date"], r["event_type"])
    if k in SHIFT:
        r["memo"] = f"{r['memo'].split(';')[0]}; met {r['date']}, statement {SHIFT[k]}"
        r["date"] = SHIFT[k]

# ---- 3. month-only convention rows ---------------------------------------------------------------------------
BOARD = "https://www.federalreserve.gov/newsevents/pressreleases/"
rows.append(dict(date="2017-10-01", event_type="balance_sheet",
                 memo="Runoff begins (source says 'in October'; first-of-month convention)",
                 source=BOARD + "monetary20170920a.htm", confidence="medium"))
rows.append(dict(date="2019-08-01", event_type="balance_sheet",
                 memo="Runoff concluded (source says 'in August'; first-of-month convention)",
                 source=BOARD + "monetary20190731a.htm", confidence="medium"))

# ---- 4. (policy_rate_regime rows, incl. intermeeting cuts, removed by decision; cycle turning points are
#         derivable from core_daily target_top / target_bottom) ------------------------------------------------

# ---- 5. inferred terminations: already medium in the candidate file; make the memo explicit ---------------------
for r in rows:
    if r["event_type"] == "facility" and r["confidence"] == "medium" and "inferred" not in r["memo"].lower():
        r["memo"] = r["memo"] + " (end inferred from final extension)"

# ---- ON RRP test / regime events: NOT imported (user, 2026-11-09): hand-crafted for another project, and the
#      ON RRP award rate itself is in core_daily. (The on_rrp_regime episodes in the draft are a separate question.)

# ---- hand-typed Normalization24 dates ----------------------------------------------------------------------------
idx = {(r["date"], r["event_type"]): r for r in rows}
HAND_FIX = {"2019-09-16": ("2019-09-17", "Repo market stress: first overnight repo operation since 2008 (spike began 09-16)", "operations", "medium"),
            "2019-05-02": ("2019-05-02", "Runoff slowdown takes effect (announced 2019-03-20)", "balance_sheet", "medium")}
for r in read("Dates_BalanceSheet_Normalization24.csv"):
    if r["Date"] in HAND_FIX:
        d, memo, et, conf = HAND_FIX[r["Date"]]
        rows.append(dict(date=d, event_type=et, memo=memo + f"; hand: {r['Memo']}",
                         source="config/sources/Dates_BalanceSheet_Normalization24.csv; NY Fed operating policy 2019-09-17", confidence=conf))
        continue
    k = (r["Date"], "balance_sheet")
    if k in idx:
        idx[k]["memo"] = idx[k]["memo"] + f"; hand: {r['Memo']}"
    else:
        rows.append(dict(date=r["Date"], event_type="balance_sheet", memo=f"hand: {r['Memo']}",
                         source="config/sources/Dates_BalanceSheet_Normalization24.csv", confidence="low"))

# ---- write events.csv ------------------------------------------------------------------------------------------------
rows.sort(key=lambda r: (r["date"], r["event_type"], r["memo"]))
seen = set()
for r in rows:
    k = (r["date"], r["event_type"])
    assert k not in seen, f"duplicate {k}"
    seen.add(k)
with open(os.path.join(ROOT, "config", "events.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["date", "event_type", "memo", "source", "confidence"])
    w.writeheader(); w.writerows(rows)

# ---- episodes (reviewed one by one with the user, 2026-11-09) ----------------------------------------------------------------------------
ep = []
def add(kind, label, start, end, basis, source, conf):
    ep.append(dict(kind=kind, label=label, start=start, end=end, basis=basis, source=source, confidence=conf))

add("recession", "2001", "2001-03-01", "2001-11-30", "NBER peak Mar 2001, trough Nov 2001 (month start/end)", "NBER business cycle dates; FRED USREC shifted +1 month", "high")
add("recession", "2007-09", "2007-12-01", "2009-06-30", "NBER peak Dec 2007, trough Jun 2009", "NBER; FRED USREC", "high")
add("recession", "2020", "2020-02-01", "2020-04-30", "NBER peak Feb 2020, trough Apr 2020", "NBER; FRED USREC", "high")
add("zlb", "ZLB 1", "2008-12-16", "2015-12-16", "target range 0-25bp introduced -> liftoff decision day", "monetary20081216b.htm; monetary20151216a.htm", "high")
add("zlb", "ZLB 2", "2020-03-15", "2022-03-16", "return to 0-25bp -> liftoff decision day", "monetary20200315a.htm; monetary20220316a.htm", "high")
add("qe", "QE1", "2008-11-25", "2010-03-31", "announcement -> purchases completed end of 2010Q1 (per 2009 statements)", "monetary20081125b.htm; end date from statements, not a separate release", "medium")
add("qe", "QE2", "2010-11-03", "2011-06-30", "announcement -> 'by the end of the second quarter of 2011'", "monetary20101103a.htm", "high")
add("mep", "MEP (Twist)", "2011-09-21", "2012-12-31", "announcement -> extension through end-2012; own kind: no change in balance-sheet size", "monetary20110921a.htm; monetary20120620a.htm", "high")
add("qe", "QE3", "2012-09-13", "2014-10-29", "announcement -> program concluded (end Oct 2014)", "monetary20120913a.htm; monetary20141029a.htm", "high")
add("qe", "Pandemic purchases", "2020-03-15", "2022-03-09", "announcement -> final purchases 'early March' 2022 (day is a convention)", "monetary20200315a.htm; monetary20211215a.htm", "medium")
add("runoff", "Runoff 1", "2017-10-01", "2019-08-01", "month-only source both ends; first-of-month convention", "monetary20170920a.htm; monetary20190731a.htm", "medium")
add("runoff", "Runoff 2", "2022-06-01", "2025-12-01", "caps apply from 2022-06-01 -> runoff concluded 2025-12-01", "monetary20220504b.htm; monetary20251029a.htm", "high")
add("rmp", "Reserve-management bills 1", "2019-10-15", "2020-03-15", "T-bill purchases start -> subsumed into pandemic purchases (convention)", "monetary20191011a.htm; monetary20200315a.htm", "medium")
add("rmp", "Reserve-management bills 2", "2025-12-11", "", "directive effective 2025-12-11; ongoing (open end)", "monetary20251210a1.htm", "high")
# ON RRP regimes: NOT episodes (user, 2026-11-09): the regime is the spread of the ON RRP rate to the target
# bottom in core_daily, and several moves were coordinated with IOR; sort it out with the rates themselves.

with open(os.path.join(ROOT, "config", "episodes.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["kind", "label", "start", "end", "basis", "source", "confidence"])
    w.writeheader(); w.writerows(ep)

from collections import Counter
print("events.csv rows:", len(rows), dict(Counter(r["event_type"] for r in rows)))
print("episodes.csv rows:", len(ep), dict(Counter(e["kind"] for e in ep)))
