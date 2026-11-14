# This is a test exercise for my-mon-pipe

The exercise demonstrates how to use the my-mon-pipe codes in a practical scenario, utilizing several features, and being informative by itself.

## Scope of Exercise

Highlight the dynamics around year and quarter ends, how they depend on the supply of reserves, administrative rates, and other factors.

We will compare the business days around year and quarter ends: +/- 2 days.
  - On spreads: Using ior as the reference rate, turn EFFR, SOFR, ONRRP rate, and primary discount rate into spreads.
  - Analyze the behavior of these spreads around year and quarter ends. The average spread on the previous two weeks will be used as a benchmark for comparison.
  - Split year and quarter ends. That is, one category is for year ends, and another category for quarter ends that are NOT a year end.
  - Collect supply data for reserves going into the year end and quarter ends. Use nominal GDP, deposits, banking assets... as possible normalization factors for the supply of reserves.
  - To utilize the rate distribution, we will also explore if the distribution of rates changes around year and quarter ends.

## Note on the implementation

The script (`year_quarter_ends.R`) keeps only the EFFR and SOFR spreads. The ON RRP rate and the
primary credit rate were dropped because both are administered rates. Their spread to IOR is set by
the FOMC and does not respond to period-end pressure. Across the 2009-2026 events it changes inside
an event's benchmark-plus-window days (t-12 to t+2) only when the FOMC changed its settings: 7 of 53
events for ON RRP (2013-14 test-phase changes, liftoff, technical adjustments) and 5 of 71 for primary
credit. A deviation from the benchmark would measure those decisions, not period-end dynamics. The
log still reports the ON RRP award rate as a data trap: FRED leaves it blank on zero-take-up days.
