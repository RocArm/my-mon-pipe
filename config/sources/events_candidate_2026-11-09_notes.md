# events_candidate.csv — collection notes

Generated 2026-11-09. Coverage 2000-01-01 to 2026-11-09. 360 rows: fomc_meeting 249, facility 52,
balance_sheet 31, policy_rate_regime 22, recession 6. Confidence: 355 high, 5 medium, 0 low.

Columns: `date,event_type,memo,source,confidence`. One row per (date, event_type); where two
same-type events fall on one day the memo combines them (e.g. 2020-03-15 facility row).

Reproducibility: raw HTML/CSV saved under `raw/` (Board pages at `raw/pr/`), scripts under
`scripts/` (`parse_fomc.py` -> `fomc_parsed.csv`; `build_events.py` -> `events_candidate.csv`).
Nothing in the hand-entered tables (C/D/E) was accepted without the named source page being fetched
and the relevant sentence read; the only "memory" items are the parenthetical operational-start dates
flagged "unverified" inside two memos (see C below).

---

## A. fomc_meeting (249 rows) — SCRAPED

Sources (all fetched 2026-11-09 with curl, parsed from HTML; no dates typed from memory):
- 2000-2020: https://www.federalreserve.gov/monetarypolicy/fomchistoricalYYYY.htm (21 pages, all reachable)
- 2021-2026 (and 2027): https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm

Extraction:
- Historical pages: every `<h5>` heading of the form "Month D[-D] <Meeting|Conference Call|(unscheduled)|(notation vote)|(cancelled)> - YYYY".
  Date = last day in the range. Month-spanning meetings ("April/May 30-1", "Jan/Feb 31-1", "Oct/Nov 31-1",
  "Jul/Aug 31-1") resolved to the second month.
- Calendar page: per-year panels; each `fomc-meeting__month` / `fomc-meeting__date` pair. Date = last day
  listed; "Apr/May 30-1" style resolved to the second month.
- SEP flag: calendar page uses `*` ("Meeting associated with a Summary of Economic Projections");
  historical pages: a panel containing a link whose text/href contains "SEP" or "Projection Materials".
  76 SEP rows: 2007 (Oct) 1; 2008-2011 4/yr; 2012 5 (Jan, Apr, Jun, Sep, Dec); 2013-2019 4/yr; 2020 3
  (March meeting cancelled); 2021-2025 4/yr; 2026 3 so far. Matches the known SEP schedule.
- Memo vocabulary: "scheduled, day N of N" / "scheduled, 1-day" / "unscheduled conference call" /
  "unscheduled meeting" / "notation vote: <topic>" ; "; SEP" appended where applicable.
  Notation-vote topics taken from the link text in the panel (Press Release / Statement / Statement on
  Longer-Run Goals); the 2020-03-19/-23/-31 topics were cross-checked against the Board releases of the
  same day (swap lines with 9 CBs; FOMC statement on open-ended purchases; FIMA repo).

Rows deliberately excluded / altered:
- 2020-03-17/18 meeting is listed as "(cancelled)" -> excluded.
- 2026-12-09 and all eight 2027 meetings are after today -> excluded (available in `fomc_parsed.csv`).
- 2003: page lists "September 15 Meeting" and "September 16 Meeting" as two separate headings. Treated as
  one two-day meeting dated 2003-09-16 (the statement date), memo flags it, confidence=medium.
  HUMAN DECISION: confirm Sept 15, 2003 was day 1 of a two-day meeting rather than a separate session.
- 2020-03-02 "(unscheduled) Meeting": the page heading says March 2 but the statement (and the cut) was
  released March 3, 2020 (Board release monetary20200303a). Kept 2020-03-02 as the fomc_meeting date per
  the page, memo notes the statement date, and the policy_rate_regime row is dated 2020-03-03.
  HUMAN DECISION: whether event date should be the meeting day or the statement day for this one case.
- 2001 and 2003 conference calls with no policy action (e.g. 2001-04-11, 2001-09-13, 2003-03-25,
  2003-04-01/08/16) are included as "unscheduled conference call"; several were war/9-11 briefings with
  no decision. Intermeeting rate actions were on 2001-01-03, 2001-04-18, 2001-09-17, 2007-08-17 (discount
  rate only, the 08-16 call), 2008-01-22 (the 01-21 call; statement released 01-22), 2008-10-08 (the
  10-07 call; coordinated cut released 10-08). Note the same one-day offset pattern for the Jan 21 and
  Oct 7, 2008 calls as for March 2, 2020: the page dates the call, the statement came the next morning.
  HUMAN DECISION: whether to shift conference-call dates with next-morning statements (2008-01-21 ->
  01-22, 2008-10-07 -> 10-08, 2020-03-02 -> 03-03). I did not shift them; the CSV follows the page.
  Verification of the statement dates named in this paragraph (all fetched): monetary20080122b (Jan 22,
  2008 FOMC statement), monetary20081008a (Oct 8, 2008 coordinated cut), monetary20070817a/b (Aug 17,
  2007 discount rate action + FOMC statement), boarddocs/press/general/2001/20010418 (Apr 18, 2001 cut),
  boarddocs/press/general/2001/20010917 (Sep 17, 2001 cut), monetary20200303a (Mar 3, 2020 cut).

## B. recession (6 rows) — SCRAPED

Source: https://fred.stlouisfed.org/graph/fredgraph.csv?id=USREC (fetched without -A; reachable; last
observation 2026-10-01 = 0).

Extraction: USREC is the NBER "peak-to-trough" indicator where 1 = the months FOLLOWING the peak month
through the trough month. Start row = first month of a run of 1s; end row = last month of the run. Dated
with FRED's first-of-month observation date.
- 2001-04-01 start / 2001-11-01 end   (NBER peak Mar 2001, trough Nov 2001)
- 2008-01-01 start / 2009-06-01 end   (NBER peak Dec 2007, trough Jun 2009)
- 2020-03-01 start / 2020-04-01 end   (NBER peak Feb 2020, trough Apr 2020)
HUMAN DECISION: (i) whether the start should be the NBER peak month itself (one month earlier than the
first USREC=1 month) — FRED's USRECP/USRECM series encode the other conventions; (ii) whether end rows
should be dated at the first or last calendar day of the trough month (first-of-month used here).

## C. facility (52 rows) — HAND-ENTERED, EACH CONFIRMED AGAINST A FETCHED BOARD/NY FED PAGE

Press-release pages fetched from https://www.federalreserve.gov/newsevents/pressreleases/<id>.htm and the
confirming sentence read (saved in raw/pr/). Confidence "high" means the row's date is the release date of
the fetched page or a date stated explicitly in it. "medium" means the date is inferred as the end of a
stated extension period with no separate termination release fetched.

| date | what | confirming page |
|---|---|---|
| 2007-12-12 | TAF created; first auction Dec 17; ECB/SNB swaps | monetary20071212a |
| 2008-03-11 | TSLF; auctions from Mar 27, 2008 | monetary20080311a |
| 2008-03-16 | PDCF; "available for business Monday March 17" | monetary20080316a |
| 2008-09-14 | PDCF/TSLF collateral broadened | monetary20080914a |
| 2008-09-18 | swap lines +$180bn, BoJ/BoE/BoC | monetary20080918a |
| 2008-09-19 | AMLF announced | monetary20080919a (ops start 09-22 is MEMORY, flagged unverified in memo) |
| 2008-10-06 / 10-09 | IOER/IORR announced; "take effect Thursday, October 9, 2008" | monetary20081006a |
| 2008-10-07 | CPFF created; began funding Oct 27, 2008 (stated in MMIFF release) | monetary20081007c, monetary20081021a |
| 2008-10-13 | swap lines BoE/ECB/SNB full allotment | monetary20081013a |
| 2008-10-21 | MMIFF | monetary20081021a |
| 2008-10-29 | swaps with Brazil, Mexico, Korea, Singapore | monetary20081029b |
| 2008-11-25 | TALF | monetary20081125a |
| 2009-02-03 | AMLF/CPFF/MMIFF/PDCF/TSLF + swaps extended to Oct 30, 2009 | monetary20090203a |
| 2009-06-25 | AMLF/CPFF/PDCF/TSLF to Feb 1, 2010; MMIFF not extended | monetary20090625a |
| 2009-08-17 | TALF to Mar 31, 2010 (ABS/legacy CMBS) and Jun 30, 2010 (new CMBS) | monetary20090817a |
| 2009-10-30 | MMIFF expiry (Feb-3 extension end + Jun-25 non-extension) | monetary20090203a + 20090625a |
| 2010-02-01 | AMLF, CPFF, PDCF, TSLF close; temp swaps expire | monetary20100127a |
| 2010-03-08 | final TAF auction | monetary20100127a |
| 2010-03-31 / 06-30 | TALF closes | monetary20090817a |
| 2010-05-09 | swap lines reestablished | monetary20100509a |
| 2013-09-23 | ON RRP daily fixed-rate exercise "beginning the week of September 23, 2013" | https://www.newyorkfed.org/markets/opolicy/operating_policy_130920.html |
| 2013-10-31 | swap lines made standing | monetary20131031a |
| 2020-03-15 | swap pricing/84-day ops (c); reserve requirements to zero eff. Mar 26 (b) | monetary20200315c, monetary20200315b |
| 2020-03-17 | CPFF (a) and PDCF (b, "available on March 20, 2020") | monetary20200317a/b |
| 2020-03-18 | MMLF announced | monetary20200318a (ops start 03-23 is MEMORY, flagged unverified) |
| 2020-03-19 | temp swaps with 9 CBs | monetary20200319b |
| 2020-03-20 | daily 7-day swap ops from Mar 23 | monetary20200320a |
| 2020-03-23 | PMCCF, SMCCF, TALF | monetary20200323b |
| 2020-03-31 | FIMA repo, available Apr 6 | monetary20200331a |
| 2020-04-06 / 04-09 | PPPLF announced / PPPLF terms + MLF + MSLP | monetary20200406a, monetary20200409a |
| 2020-06-15 | SMCCF begins buying bonds | monetary20200615a |
| 2020-07-28 | facilities extended to Dec 31, 2020 | monetary20200728a |
| 2020-11-30 | CPFF, MMLF, PDCF, PPPLF extended to Mar 31, 2021 | monetary20201130a |
| 2020-12-16 | temp swaps + FIMA repo to Sep 30, 2021 | monetary20201216c |
| 2020-12-29 / 2021-01-08 | MSLP termination moved to Jan 8, 2021 | monetary20201229a |
| 2020-12-31 | PMCCF, SMCCF, MLF, TALF cease — MEDIUM: inferred from Nov-30 release ("generally scheduled to expire on or around December 31") and the Jul-28 release; the Treasury Nov 19, 2020 letter was not fetched | monetary20201130a |
| 2021-03-08 / 06-25 / 07-30 | PPPLF to Jun 30; final extension to Jul 30, 2021; cease | monetary20210308a, monetary20210625a |
| 2021-03-31 | CPFF, PDCF, MMLF cease — MEDIUM: end of extension; no separate termination release fetched | monetary20201130a |
| 2021-06-02 / 07-29 | IORB rule "takes effect on Thursday, July 29, 2021" | bcreg20210602a |
| 2021-06-16 | temp swaps (9 CBs) to Dec 31, 2021 | monetary20210616c |
| 2021-07-28 | SRF + standing FIMA repo | monetary20210728b |
| 2021-12-31 | temp swaps expire — MEDIUM: end of final extension, no termination release fetched | monetary20210616c |
| 2023-03-12 | BTFP | monetary20230312a |
| 2024-01-24 / 03-11 | BTFP ceases new loans Mar 11 | monetary20240124a |

Not included (could not verify from a fetched page, or out of scope): operational start dates of the 2020
facilities other than PDCF (CPFF 2020 ops Apr 14, MMLF Mar 23, PPPLF Apr 16, MLF May 26, MSLP Jul 6, TALF
Jun 17 — all memory, left out); the Dec 2015 "Decisions Regarding Monetary Policy Implementation" page
(monetary20151216a1 returned Page Not Found), so no separate ON RRP full-scale/cap-change row for
2015-12-17; the temporary FIMA repo expiry (it was converted to standing on 2021-07-28, which is included);
reserve requirement change is folded into the 2020-03-15 facility row — HUMAN DECISION whether it belongs
in facility or policy_rate_regime.

## D. balance_sheet (31 rows) — HAND-ENTERED, EACH CONFIRMED AGAINST THE FETCHED STATEMENT / IMPLEMENTATION NOTE

All from https://www.federalreserve.gov/newsevents/pressreleases/<id>.htm; confirming sentence read.
- 2008-11-25 QE1 (monetary20081125b); 2009-03-18 expansion (monetary20090318a)
- 2010-08-10 reinvestment policy (monetary20100810a) — extra, not in the request
- 2010-11-03 QE2 (monetary20101103a)
- 2011-09-21 MEP (monetary20110921a); 2012-06-20 extension (monetary20120620a)
- 2012-09-13 QE3 MBS (monetary20120913a); 2012-12-12 QE3 Treasuries (monetary20121212a)
- 2013-12-18 taper (monetary20131218a); 2014-09-17 Normalization Principles (monetary20140917c) — extra;
  2014-10-29 purchases end (monetary20141029a)
- 2017-06-14 addendum (monetary20170614c); 2017-09-20 "In October, the Committee will initiate..."
  (monetary20170920a). NO row for the October 2017 start itself: the statement gives only the month.
  HUMAN DECISION: add 2017-10-01 (or the first October maturity date) as a convention row if wanted.
- 2019-01-30 ample-reserves statement (monetary20190130c) — extra; 2019-03-20 (monetary20190320c);
  2019-07-31 "conclude ... in August" (monetary20190731a) — no separate Aug 1 row (statement says "in
  August", no day); 2019-10-11 reserve-management purchases "Effective October 15, 2019" (monetary20191011a)
- 2020-03-15 (monetary20200315a); 2020-03-23 (monetary20200323a); 2020-12-16 guidance (monetary20201216a) — extra
- 2021-11-03 taper (monetary20211103a); 2021-12-15 taper doubled (monetary20211215a) — extra
- 2022-01-26 Principles (monetary20220126c) — extra; 2022-05-04 Plans "Beginning on June 1" (monetary20220504b);
  2022-06-01 runoff start (same page)
- 2024-05-01 "Beginning in June ... $60 billion to $25 billion" (monetary20240501a)
- 2025-03-19 "Beginning in April ... $25 billion to $5 billion" (monetary20250319a) — extra
- 2025-10-29 "The Committee decided to conclude the reduction of its aggregate securities holdings on
  December 1" (monetary20251029a; implementation note a1: from Dec 1 roll over all Treasury principal and
  reinvest agency principal into T-bills); 2025-12-01 runoff end row dated from that text.
- 2025-12-10 implementation note (monetary20251210a1): directive "Effective December 11, 2025 ... Increase
  the System Open Market Account holdings of securities through purchases of Treasury bills and, if needed,
  other Treasury securities with remaining maturities of 3 years or less to maintain an ample level of
  reserves" — i.e. reserve-management purchases start. Same language in the Jan 28, Mar 18, Apr 29, 2026 notes.
- 2026-06-17 implementation note (monetary20260617a1): language changes to "When appropriate, increase the
  SOMA holdings ..." and stays that way in Jul 29, Sep 16, Oct 28, 2026 notes. Entered as "RMP directive
  softened", confidence=medium because the interpretation (pause of regular purchases) is mine; the date is
  firm. HUMAN DECISION: keep, relabel, or drop. No NY Fed Desk statement on RMP pace was fetched.
- 2026 statements checked for other balance-sheet changes (Jan 28, Mar 18, Apr 29, Jun 17, Jul 29, Sep 16,
  Oct 28): none found beyond the above. ON RRP per-counterparty limit stayed $160bn throughout.

## E. policy_rate_regime (22 rows) — HAND-ENTERED, EACH CONFIRMED

Cycle turning points (date = statement date; the "first/last of cycle" label is my classification):
- 2000-05-16 last hike (boarddocs/press/general/2000/20000516); 2001-01-03 first cut, intermeeting
  (boarddocs/press/general/2001/20010103); 2003-06-25 last cut (boarddocs/press/monetary/2003/20030625);
  2004-06-30 first hike (boarddocs/press/monetary/2004/20040630); 2006-06-29 last hike (monetary20060629a);
  2007-09-18 first cut (monetary20070918a); 2008-12-16 target range introduced (monetary20081216b);
  2015-12-16 liftoff (monetary20151216a); 2018-12-19 last hike (monetary20181219a); 2019-07-31 first cut
  (monetary20190731a); 2020-03-03 intermeeting cut (monetary20200303a); 2020-03-15 return to ZLB
  (monetary20200315a); 2022-03-16 liftoff (monetary20220316a); 2023-07-26 last hike (monetary20230726a);
  2024-09-18 first cut (monetary20240918a); 2025-09-17 cuts resume after the Jan-Jul 2025 hold
  (monetary20250917a; Jul 30, 2025 hold confirmed via monetary20250730a); 2025-12-10 cut (monetary20251210a)
  labelled "last cut of 2024-25 cycle (as of 2026-11-09)" because 2026 statements show holds through Jul 29
  and a hike on Sep 16; 2026-09-16 "decided to raise the target range by 1/4 percentage point"
  (monetary20260916a).
Administered-rate technical adjustments (from implementation notes): 2018-06-13 (IOER 5bp below top,
monetary20180613a1); 2019-05-01 (15bp below, monetary20190501a1); 2019-09-18 (20bp below,
monetary20190918a1); 2021-06-16 (IOER 15bp above bottom, ON RRP 0.05, monetary20210616a1).
Not included: the 2001-04-18 and 2001-09-17 intermeeting cuts and the 2008-01-22 / 2008-10-08 intermeeting
cuts (they appear as fomc_meeting conference-call rows; see the dating caveat in A). HUMAN DECISION:
whether intermeeting actions should also get policy_rate_regime rows.
The IORB start (2021-07-29) and IOER start (2008-10-09) are in facility, not duplicated here.

## Reachability summary
Reachable: fomccalendars.htm; fomchistorical2000-2020.htm (all 21); FRED USREC; all Board press releases
listed above (new-pattern URLs) plus four old-pattern boarddocs pages (2000-05-16, 2001-01-03, 2003-06-25,
2004-06-30); NY Fed operating_policy_130920.
Not found (404): monetary20090625b, monetary20210625b (the "a" variants were the right pages and were
used); monetary20151216a1; monetary20191011a1; monetary20080930a; monetary20090916a; monetary20100201a;
old-pattern monetary20010103a / 20000516a / 20030625a / 20040630a (the boarddocs/press paths were used instead).
Not attempted: Treasury letter of 2020-11-19 on CARES facilities; NY Fed Desk statements on RMP pace.
