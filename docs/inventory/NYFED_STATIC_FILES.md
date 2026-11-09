# NY Fed static reference-rate history files

Downloaded 2026-10-28 from https://www.newyorkfed.org/markets/reference-rates/additional-information-about-reference-rates
(section "Additional Reference Rate Data"). These are one-off historical files with no API equivalent.

| File | NY Fed link text | URL | Content |
|---|---|---|---|
| indicative_repo_2014_2018.xlsx | Daily indicative TGCR, BGCR, and SOFR volume and rate data (Aug. 2014 - Mar. 2018) | https://www.newyorkfed.org/medialibrary/media/markets/Data%20Release.xlsx | Sheets: Volumes ($bn), VWM Rates (basis points), Geometric Mean (3-month, bp). Daily, 2014-08-22 to 2018-03-29. Byte-identical (MD5) to repomak/codes_techadj/data/manual/HistorySOFR.xlsx. |
| ff_volumes_2006_2016.xlsx | Daily brokered Fed Funds volumes and percentiles (Oct. 2006 - Feb. 2016) | https://www.newyorkfed.org/medialibrary/media/markets/ff-volumes-oct2006-feb2016.xlsx | Sheet1: Date, 1st/25th/50th/75th/99th percentile rate (percent), Volume. Daily, 2006-10-02 to 2016-02-29. Pre-FR 2420 brokered data; extends EFFR percentiles/volume (FRED/API start 2016-03-01) back to 2006. |
| indicative_sofr_avg_2018_2020.xlsx | Daily indicative SOFR averages and index (Apr. 2018 - Feb. 2020) | https://www.newyorkfed.org/medialibrary/media/markets/historical_indicative_sofr_avg_ind_data.xlsx | Sheet Data: Date, SOFR Index, 30/90/180-day average SOFR. Daily, 2018-04-02 to 2020-02-28. Official series start 2020-03-02 (API type SOFRAI). |

Layout: title in row 1, header in row 2 (row 1 for ff_volumes), data from row 3; a Series/Description/Units metadata block sits to the right of the data columns.
