# 08_aux6_fedwire.R -- aux6: Fedwire Funds Service volume and value statistics (frbservices.org, no API).
#
#   monthly    ASCII text file linked from the monthly page, 2007-01 on (the page's own HTML table starts
#              2015-01 and is kept as a cross-check)
#   quarterly  ASCII text file linked from the quarterly page, 1992Q1 on (HTML table: same span, cross-check)
#   annual     HTML table on the annual page, 1987 on (no text file is offered)
#
# The text-file name carries the release (e.g. 102026-monthly-september-funds-ascii.txt), so the link is read
# off the page on every build. Nothing about the layout is assumed silently: the header and footer text, the
# number of fields per row, the period labels, the number format, the span and the arithmetic between columns
# are all checked, and any departure stops with "aux6 BROKEN PIPE: ...". The same checks run again in
# tests/run_tests.R on the cached raw files (fedwire_checks()).
#
# Output (long): series fedwire_funds_m (stats count, value, days, daily_count, daily_value) and
# fedwire_funds_q / _a (count, value); unit count or usd_mn; dated on the first day of the period (a flow
# over the period, FRED's convention). Quarterly and annual daily averages are not kept: three published
# quarters divide by the wrong number of days (config/fedwire_known_issues.csv), and Fedwire's business days
# equal the calendar's, so value / business days rebuilds them exactly. Growth rates and value per transfer
# are not kept either. All of these are still parsed: their arithmetic is a check on the layout.

FW_BASE  <- "https://www.frbservices.org/resources/financial-services/wires/volume-value-stats/"
FW_PAGES <- c(m = "fedwire-funds-service-monthly-statistics", q = "fedwire-funds-service-quarterly-statistics",
              a = "fedwire-funds-service-annual-statistics")
FW_FREQ_WORD <- c(m = "monthly", q = "quarterly", a = "annual")
FW_COLS <- list(
  txt_m = c("count", "growth_count", "value", "growth_value", "avg_value", "days", "daily_count", "daily_value"),
  txt_q = c("count", "growth_count", "value", "growth_value", "avg_value", "daily_count", "daily_value"),
  html  = c("count", "growth_count", "value", "growth_value", "avg_value", "daily_count", "daily_value"))
FW_KEEP <- list(m = c("count", "value", "days", "daily_count", "daily_value"), q = c("count", "value"), a = c("count", "value"))

# Layout fingerprints as published on 2026-11-16 (see .fw_fingerprint). A change in any of them stops the
# build: read the new page or file, confirm the columns still mean the same, then update the string here.
FW_TXT_HEADER <- c(
  m = paste("Fedwire Funds Services - Monthly Statistics Average Average Monthly Value of Monthly Average daily daily",
            "Transfers volume transfers value value per volume of value of originated growth originated growth transfer",
            "Number of transfers transfers Month (number) (percent) ($ millions) (percent) ($ millions) days (number) ($ millions)"),
  q = paste("Fedwire Funds Service - Quarterly Data Quarterly Value of Quarterly Average Average Average Transfers volume",
            "transfers value value per daily volume daily value originated growth originated growth transfer of transfers",
            "of transfers Quarter (number) (percent) ($ millions) (percent) ($ millions) (number) ($ millions)"))
FW_TXT_FOOTER <- c(
  m = "NOTE: Funds transfer data exclude non value transfers. Based on the number of business days per period.",
  q = paste("NOTE: Funds transfer data exclude non value transfers. Amounts in bold were restated in March 2007.",
            "Based on the number of business days per period. Source: PACS database: Funds Transfer - 97464($); 97473(#)"))
FW_HTML_HEADER <- c(
  m = paste("Month Transfers originated (number) Monthly volume growth (percent) Value of transfers originated ($millions)",
            "Monthly value growth (percent) Average value per transfer ($millions) Average daily volume of transfers 1 (number)",
            "Average daily value of transfers 2 ($millions)"),
  q = paste("Quarter Transfers originated (number) 1 Quarterly volume growth (percent) Value of transfers originated ($millions)",
            "Quarterly value growth (percent) Average value per transfer ($millions) Average daily volume of transfers 2 (number)",
            "Average daily value of transfers ($millions) 3"),
  a = paste("Year Transfers originated (number) Annual volume growth (percent) Value of transfers originated 1 ($millions)",
            "Annual value growth (percent) Average value per transfer ($millions) Average daily volume of transfers 2 (number)",
            "Average daily value of transfers 3 ($millions)"))
FW_HTML_NOTES <- c(
  m = paste("Notes Funds transfer data exclude non-value transfers. Source: PACS data: Funds Transfer - 97464($); 97473(#)",
            "Based on the number of business days per period. See footnote 1."),
  q = paste("Notes: Amounts in bold were restated in March 2007. Based on the number of business days per period.",
            "See Footnote 2 The 2016:Q2 data were revised on July 26, 2016."),
  a = "Notes Amounts in bold were restated in March 2007. Based on the number of business days per period. See footnote 2.")

fw_broken <- function(...)stop("aux6 BROKEN PIPE: ", paste0(..., collapse = ""), call. = FALSE)

# ---- text helpers ---------------------------------------------------------------------------------------
# A layout fingerprint: ASCII only (superscript footnote marks and dashes dropped), whitespace collapsed.
.fw_fingerprint <- function(x) {
  x <- iconv(paste(x, collapse = " "), "UTF-8", "ASCII", sub = " ")
  str_squish(x)
}
.fw_html_text <- function(x) {
  x <- gsub("<[^>]+>", " ", x)
  x <- gsub("&nbsp;|&#160;", " ", x); x <- gsub("&amp;|&#038;", "&", x)
  x <- gsub("&#821[12];|&ndash;|&mdash;", "-", x); x <- gsub("&#?[A-Za-z0-9]+;", " ", x)
  str_squish(x)
}
# "(8.5)" -> -8.5; "1,234" -> 1234; a token with no digit and no letter ("--", a dash) -> NA; anything else breaks
.fw_num <- function(tok, where) {
  t <- gsub(",", "", str_squish(tok))
  neg <- grepl("^\\(.*\\)$", t); t <- gsub("^\\(|\\)$", "", t)
  na <- !grepl("[0-9A-Za-z]", t)
  good <- na | grepl("^-?[0-9]+([.][0-9]+)?$", t)
  if (!all(good)) fw_broken(where, ": unparseable number(s): ", paste(head(unique(tok[!good]), 5), collapse = " | "))
  v <- suppressWarnings(as.numeric(t)); v[neg] <- -v[neg]; v[na] <- NA
  v
}
# Period label -> first day of the period. Months are read from their first three letters ("Sept", "Feburary").
.fw_period <- function(year, lab, freq, where) {
  y <- as.integer(year)
  if (freq == "a") return(as.Date(sprintf("%d-01-01", y)))
  if (freq == "q") {
    bad <- !grepl("^Q[1-4]$", lab)
    if (any(bad)) fw_broken(where, ": unknown quarter label(s): ", paste(head(unique(lab[bad]), 5), collapse = ", "))
    return(as.Date(sprintf("%d-%02d-01", y, (as.integer(substr(lab, 2, 2)) - 1) * 3 + 1)))
  }
  k <- match(tolower(substr(lab, 1, 3)), tolower(month.abb))
  bad <- is.na(k) | !grepl("^[A-Za-z]{3,9}$", lab)
  if (any(bad)) fw_broken(where, ": unknown month label(s): ", paste(head(unique(lab[bad]), 5), collapse = ", "))
  as.Date(sprintf("%d-%02d-01", y, k))
}
# Shape rules shared by every table: unique contiguous periods, values everywhere except the growth rates
# of the earliest period.
.fw_shape <- function(df, freq, where) {
  df <- df %>% arrange(date)
  if (anyDuplicated(df$date)) fw_broken(where, ": duplicated period(s): ", paste(format(df$date[duplicated(df$date)]), collapse = ", "))
  step <- c(m = "month", q = "quarter", a = "year")[[freq]]
  full <- seq(min(df$date), max(df$date), by = step)
  if (!identical(full, df$date)) fw_broken(where, ": periods are not contiguous (missing: ",
                                           paste(format(head(as.Date(setdiff(full, df$date), origin = "1970-01-01"), 5)), collapse = ", "), ")")
  growth <- startsWith(names(df), "growth_")
  na_level <- is.na(as.matrix(df[, setdiff(names(df), c("date", names(df)[growth]))]))
  na_growth <- is.na(as.matrix(df[-1, growth]))
  if (any(na_level) || any(na_growth)) fw_broken(where, ": missing value(s) outside the first period's growth rates")
  df
}

# ---- parsers ----------------------------------------------------------------------------------------------
fedwire_parse_txt <- function(txt, freq) {
  where <- paste0(FW_FREQ_WORD[[freq]], " text file")
  lines <- sub("\\s+$", "", strsplit(txt, "\r?\n")[[1]])
  is_row <- grepl("^\\s*[0-9]{4}\\s*:", lines)
  if (sum(is_row) < 50) fw_broken(where, ": fewer than 50 data rows (", sum(is_row), ")")
  i1 <- min(which(is_row)); i2 <- max(which(is_row))
  stray <- lines[i1:i2][!is_row[i1:i2] & nzchar(trimws(lines[i1:i2]))]
  if (length(stray)) fw_broken(where, ": unexpected line(s) among the data rows: ", paste(head(stray, 3), collapse = " | "))
  hdr <- .fw_fingerprint(lines[seq_len(i1 - 1)])
  ftr <- .fw_fingerprint(lines[-seq_len(i2)])
  if (!identical(hdr, FW_TXT_HEADER[[freq]])) fw_broken(where, ": header text changed. Now: '", hdr, "'")
  if (!identical(ftr, FW_TXT_FOOTER[[freq]])) fw_broken(where, ": footnote text changed. Now: '", ftr, "'")
  m <- str_match(lines[is_row], "^\\s*([0-9]{4})\\s*:\\s*([A-Za-z0-9]+)\\s+(.*)$")
  if (anyNA(m[, 1])) fw_broken(where, ": unreadable row(s): ", paste(head(lines[is_row][is.na(m[, 1])], 3), collapse = " | "))
  cols <- FW_COLS[[paste0("txt_", freq)]]
  toks <- strsplit(str_squish(m[, 4]), " ", fixed = TRUE)
  n <- lengths(toks)
  if (any(n != length(cols))) fw_broken(where, ": row(s) with ", paste(unique(n[n != length(cols)]), collapse = "/"),
                                        " fields instead of ", length(cols), ": ", paste(head(lines[is_row][n != length(cols)], 2), collapse = " | "))
  v <- matrix(.fw_num(unlist(toks), where), ncol = length(cols), byrow = TRUE, dimnames = list(NULL, cols))
  .fw_shape(bind_cols(tibble(date = .fw_period(m[, 2], m[, 3], freq, where)), as_tibble(v)), freq, where)
}

fedwire_parse_html <- function(html, freq) {
  where <- paste0(FW_FREQ_WORD[[freq]], " page table")
  tabs <- str_extract_all(html, regex("<table.*?</table>", dotall = TRUE, ignore_case = TRUE))[[1]]
  if (length(tabs) != 1) fw_broken(where, ": ", length(tabs), " <table> elements on the page instead of 1")
  rows <- str_extract_all(tabs, regex("<tr.*?</tr>", dotall = TRUE, ignore_case = TRUE))[[1]]
  cells <- map(rows, ~ .fw_html_text(str_match_all(.x, regex("<t[hd][^>]*>(.*?)</t[hd]>", dotall = TRUE, ignore_case = TRUE))[[1]][, 2]))
  hdr <- .fw_fingerprint(cells[[1]])
  if (!identical(hdr, FW_HTML_HEADER[[freq]])) fw_broken(where, ": column headers changed. Now: '", hdr, "'")
  notes <- .fw_fingerprint(.fw_html_text(str_match(html, regex("</table>(.*?)Top of Page", dotall = TRUE))[, 2]))
  if (!identical(notes, FW_HTML_NOTES[[freq]])) fw_broken(where, ": notes under the table changed. Now: '", notes, "'")
  body <- cells[-1]
  if (length(body) < 30) fw_broken(where, ": fewer than 30 data rows (", length(body), ")")
  cols <- FW_COLS$html
  n <- lengths(body)
  if (any(n != length(cols) + 1)) fw_broken(where, ": row(s) with ", paste(unique(n[n != length(cols) + 1]), collapse = "/"),
                                            " cells instead of ", length(cols) + 1)
  lab <- map_chr(body, 1)
  # a label may carry a footnote mark as its own token ("2016:Q2 4": the 2016:Q2 revision note)
  pat <- if (freq == "a") "^([0-9]{4})()(?: [0-9])?$" else "^([0-9]{4})\\s*:\\s*(Q[1-4]|[A-Za-z]+)(?: [0-9])?$"
  m <- str_match(lab, pat)
  if (anyNA(m[, 1])) fw_broken(where, ": unreadable period label(s): ", paste(head(lab[is.na(m[, 1])], 3), collapse = ", "))
  v <- matrix(.fw_num(unlist(map(body, ~ .x[-1])), where), ncol = length(cols), byrow = TRUE, dimnames = list(NULL, cols))
  .fw_shape(bind_cols(tibble(date = .fw_period(m[, 2], m[, 3], freq, where)), as_tibble(v)), freq, where)
}

# Page facts: "Last updated on <date>" and the link to the text file (exactly one .txt link on the
# monthly and quarterly pages, none expected on the annual page).
fedwire_page_meta <- function(html, freq) {
  where <- paste0(FW_FREQ_WORD[[freq]], " page")
  title <- .fw_html_text(str_match(html, regex("<title>(.*?)</title>", dotall = TRUE, ignore_case = TRUE))[, 2])
  want <- paste0("Fedwire Funds Service - ", str_to_title(FW_FREQ_WORD[[freq]]), " Statistics")
  if (is.na(title) || !startsWith(.fw_fingerprint(title), .fw_fingerprint(want)))
    fw_broken(where, ": page title is '", title, "', expected it to start with '", want, "'")
  upd <- mdy(str_match(html, "Last updated on ([A-Z][a-z]+ [0-9]{1,2}, [0-9]{4})")[, 2], quiet = TRUE)
  if (is.na(upd)) fw_broken(where, ": no 'Last updated on <Month d, yyyy>' line")
  links <- unique(str_match_all(html, "href=\"([^\"]+[.]txt)\"")[[1]][, 2])
  if (freq != "a") {
    if (length(links) != 1) fw_broken(where, ": ", length(links), " links to .txt files instead of 1: ", paste(links, collapse = ", "))
    if (!grepl(FW_FREQ_WORD[[freq]], basename(links), ignore.case = TRUE))
      fw_broken(where, ": the text file '", basename(links), "' does not name the ", FW_FREQ_WORD[[freq]], " series")
  }
  list(updated = upd, txt_url = if (length(links)) links[1] else NA_character_, title = title)
}

# ---- fetch -------------------------------------------------------------------------------------------------
# Every file is cached as received under data/raw/frbservices/. Returns the parsed tables and page facts.
fedwire_fetch <- function() {
  out <- list()
  for (f in names(FW_PAGES)) {
    html <- frbs_get(paste0(FW_BASE, FW_PAGES[[f]], "/"), paste0(FW_FREQ_WORD[[f]], "_page"), "html", "text/html")
    meta <- fedwire_page_meta(html, f)
    out[[paste0("meta_", f)]] <- meta
    out[[paste0("html_", f)]] <- fedwire_parse_html(html, f)
    if (f != "a") {
      txt <- frbs_get(meta$txt_url, FW_FREQ_WORD[[f]], "txt", "text/plain")
      out[[paste0("txt_", f)]] <- fedwire_parse_txt(txt, f)
    } else if (!is.na(meta$txt_url)) {
      log_line("NOTE aux6: the annual page now links a text file (", meta$txt_url, "); the annual series still reads the HTML table")
    }
  }
  out
}
# Re-read the latest cached raw files (tests; revision comparison). before = only files dated before this day.
fedwire_from_cache <- function(before = NULL) {
  dir <- pipe_path("data", "raw", "frbservices")
  pick <- function(name, ext) {
    fs <- sort(list.files(dir, pattern = paste0("^", name, "_[0-9]{8}[.]", ext, "$"), full.names = TRUE))
    if (!is.null(before)) fs <- fs[as.Date(str_extract(basename(fs), "[0-9]{8}"), "%Y%m%d") < before]
    if (length(fs)) tail(fs, 1) else NA_character_
  }
  rd <- function(p) { x <- readChar(p, file.size(p), useBytes = TRUE); Encoding(x) <- "UTF-8"; x }
  out <- list()
  for (f in names(FW_PAGES)) {
    p <- pick(paste0(FW_FREQ_WORD[[f]], "_page"), "html")
    if (is.na(p)) return(NULL)
    html <- rd(p)
    out[[paste0("meta_", f)]] <- fedwire_page_meta(html, f)
    out[[paste0("html_", f)]] <- fedwire_parse_html(html, f)
    if (f != "a") {
      p <- pick(FW_FREQ_WORD[[f]], "txt")
      if (is.na(p)) return(NULL)
      out[[paste0("txt_", f)]] <- fedwire_parse_txt(rd(p), f)
    }
  }
  out
}

# ---- checks ------------------------------------------------------------------------------------------------
# Each check returns the periods that fail it. A check passes when that set equals the periods listed for
# it in config/fedwire_known_issues.csv: a new failure is flagged, and so is a listed issue that has
# disappeared (the source was corrected: remove the row). Tolerances follow the published rounding:
# counts exact, $ millions to 1 (2 when summing), daily averages to 1, value per transfer to 0.01 (one row
# shows 4.9), growth rates to 0.1.
read_fedwire_known <- function() {
  read_csv(pipe_path("config", "fedwire_known_issues.csv"), show_col_types = FALSE,
           col_types = cols(date = col_date(), .default = col_character()))
}

fedwire_checks <- function(p, cal, reg = read_registry(), known = read_fedwire_known()) {
  out <- list()
  add <- function(id, fails) {
    fails <- sort(unique(as.Date(fails, origin = "1970-01-01")))
    want <- sort(unique(known$date[known$check == id]))
    new <- fails[!fails %in% want]; gone <- want[!want %in% fails]
    out[[id]] <<- tibble(check = id, pass = !length(new) && !length(gone),
                         detail = paste0(length(fails), " failing period(s), ", length(want), " known",
                                         if (length(new)) paste0("; NEW: ", paste(format(new), collapse = ", ")) else "",
                                         if (length(gone)) paste0("; listed but no longer failing (source corrected? remove from config): ",
                                                                  paste(format(gone), collapse = ", ")) else ""))
  }
  tabs <- c("txt_m", "txt_q", "html_m", "html_q", "html_a")
  freq_of <- function(t) substr(t, nchar(t), nchar(t))
  g <- function(x) 100 * (x / lag(x) - 1)

  # 1. arithmetic inside each table (catches swapped or shifted columns)
  for (t in tabs) {
    d <- p[[t]]
    add(paste0("identity_avg_", t), d$date[abs(d$avg_value - d$value / d$count) > 0.0101])
    add(paste0("identity_growth_", t), d$date[which(abs(d$growth_count - g(d$count)) > 0.06 | abs(d$growth_value - g(d$value)) > 0.06)])
  }
  for (t in c("txt_m", "html_m")) {
    d <- p[[t]] %>% select(-any_of("days")) %>% inner_join(p$txt_m %>% select(date, days), by = "date")
    add(paste0("identity_daily_", t), d$date[abs(d$daily_count - d$count / d$days) > 1 | abs(d$daily_value - d$value / d$days) > 1])
  }
  # 2. business days: published (months) or implied by the daily averages (quarters, years) = our calendar,
  #    for every period that lies wholly inside it. The two match in every month since 2007.
  unit_of <- c(m = "month", q = "quarter", a = "year")
  cal_days <- function(unit) cal %>% mutate(period = floor_date(date, unit)) %>% group_by(period) %>%
    summarise(cal_n = sum(is_bday), first = min(date), last = max(date), .groups = "drop") %>%
    filter(first == period, last == ceiling_date(period, unit) - 1) %>% select(date = period, cal_n)
  for (t in c("txt_m", "txt_q", "html_q", "html_a")) {
    d <- p[[t]] %>% inner_join(cal_days(unit_of[[freq_of(t)]]), by = "date")
    bad <- if (t == "txt_m") d$date[d$days != d$cal_n] else
      d$date[abs(d$count / d$daily_count - d$cal_n) > 0.01 | abs(d$value / d$daily_value - d$cal_n) > 0.01]
    add(paste0("days_", t), bad)
  }
  # 3. the two renderings of the same release agree (monthly HTML from 2015, quarterly over the full span)
  tol <- c(count = 0, value = 2, daily_count = 1, daily_value = 1, avg_value = 0.0101, growth_count = 0.11, growth_value = 0.11)
  lng <- function(d) d %>% select(date, all_of(names(tol))) %>% pivot_longer(-date, names_to = "col")
  for (f in c("m", "q")) {
    a <- p[[paste0("txt_", f)]]; b <- p[[paste0("html_", f)]]
    j <- inner_join(lng(a), lng(b), by = c("date", "col"))
    add(paste0("txt_vs_html_", f), j$date[abs(j$value.x - j$value.y) > tol[j$col]])
    add(paste0("same_release_", f), if (max(a$date) != max(b$date)) max(a$date) else NULL)
  }
  # 4. months add up to quarters, quarters to years (count exact, value within rounding)
  roll <- function(d, unit, k) d %>% mutate(date = floor_date(date, unit)) %>% group_by(date) %>%
    summarise(n = n(), count = sum(count), value = sum(value), .groups = "drop") %>% filter(n == k)
  s <- roll(p$txt_m, "quarter", 3) %>% inner_join(p$txt_q, by = "date")
  add("sum_m_to_q", s$date[s$count.x != s$count.y | abs(s$value.x - s$value.y) > 2])
  s <- roll(p$txt_q, "year", 4) %>% inner_join(p$html_a, by = "date")
  add("sum_q_to_a", s$date[s$count.x != s$count.y | abs(s$value.x - s$value.y) > 2])
  # 5. magnitudes (a switch to $ billions, or to thousands of transfers, lands outside)
  for (t in tabs) {
    d <- p[[t]]
    days_bad <- if ("days" %in% names(d)) d$days < 15 | d$days > 23 else FALSE
    add(paste0("bands_", t), d$date[d$avg_value < 1 | d$avg_value > 20 | d$daily_value < 2e5 | d$daily_value > 3e7 |
                                      d$daily_count < 5e4 | d$daily_count > 5e6 | days_bad])
  }
  # 6. history starts where it did when verified (a truncated table would otherwise pass)
  src_tab <- c(m = "txt_m", q = "txt_q", a = "html_a")
  for (f in names(src_tab)) {
    want <- as.Date(unique(reg$start_expected[reg$name == paste0("fedwire_funds_", f)]))
    got <- min(p[[src_tab[[f]]]]$date)
    add(paste0("start_", f), if (length(want) != 1 || got != want) got else NULL)
  }
  # 7. the page's "Last updated" date follows the end of the last period by 0 to 90 days
  for (f in names(src_tab)) {
    last <- max(p[[src_tab[[f]]]]$date)
    lag <- as.numeric(p[[paste0("meta_", f)]]$updated - (ceiling_date(last, unit_of[[f]]) - 1))
    add(paste0("updated_", f), if (lag < 0 || lag > 90) last else NULL)
  }
  bind_rows(out)
}

# ---- build -------------------------------------------------------------------------------------------------
# Long table from the text files (m, q) and the annual HTML table. Registry rows fedwire_funds_<f> / stat
# give the unit and multiplier; a parsed stat without a registry row, or the reverse, breaks the pipe.
fedwire_long <- function(p, reg) {
  rows <- reg %>% filter(pipe == "aux6")
  src <- list(m = list(d = p$txt_m, s = basename(p$meta_m$txt_url)), q = list(d = p$txt_q, s = basename(p$meta_q$txt_url)),
              a = list(d = p$html_a, s = FW_PAGES[["a"]]))
  out <- imap(src, function(x, f) {
    nm <- paste0("fedwire_funds_", f)
    r <- rows %>% filter(name == nm)
    have <- intersect(FW_KEEP[[f]], names(x$d))
    if (!setequal(have, r$stat)) fw_broken("registry rows for ", nm, " (", paste(r$stat, collapse = ", "),
                                           ") do not match the parsed columns (", paste(have, collapse = ", "), ")")
    map(seq_len(nrow(r)), function(i) {
      as_long(tibble(date = x$d$date, value = x$d[[r$stat[i]]]), nm, r$stat[i], r$source_unit[i], paste0("frbservices:", x$s)) %>%
        apply_multiplier(r$multiplier[i], r$target_unit[i])
    }) %>% bind_rows()
  }) %>% bind_rows() %>% arrange(series, stat, date)
  check_long(out)
}

# Values that changed since the latest download from an earlier day are logged: restatements are
# legitimate but should be seen. Never fails the build.
fedwire_log_revisions <- function(new) {
  old <- tryCatch(fedwire_from_cache(before = Sys.Date()),
                  error = function(e) { log_line("NOTE aux6: earlier download unreadable: ", conditionMessage(e)); NULL })
  if (is.null(old)) { log_line("aux6: no earlier download to compare with"); return(invisible(NULL)) }
  lng <- function(d, f) d %>% select(date, all_of(FW_KEEP[[f]])) %>% pivot_longer(-date, names_to = "col")
  for (t in c("txt_m", "txt_q", "html_a")) {
    f <- substr(t, nchar(t), nchar(t))
    j <- inner_join(lng(old[[t]], f), lng(new[[t]], f), by = c("date", "col")) %>% filter(value.x != value.y)
    if (nrow(j)) log_line("WARNING aux6: ", nrow(j), " value(s) in ", t, " revised since the earlier download; periods ",
                          paste(format(sort(unique(j$date))), collapse = ", "))
  }
  invisible(NULL)
}

build_aux6 <- function(reg, cal) {
  log_line("== aux6: Fedwire Funds Service statistics (frbservices.org)")
  p <- fedwire_fetch()
  fedwire_log_revisions(p)
  out <- fedwire_long(p, reg)
  for (f in c("m", "q", "a")) {
    d <- out %>% filter(series == paste0("fedwire_funds_", f))
    log_line(sprintf("%-38s    %s -> %s  n=%5d  stats=%s  page updated %s", paste0("fedwire_funds_", f), format(min(d$date)),
                     format(max(d$date)), n_distinct(d$date), paste(unique(d$stat), collapse = "/"), format(p[[paste0("meta_", f)]]$updated)))
  }
  chk <- fedwire_checks(p, cal, reg)
  if (!all(chk$pass)) log_line("WARNING aux6: ", sum(!chk$pass), " check(s) fail, the tests will stop: ",
                               paste(chk$check[!chk$pass], collapse = ", "))
  out
}
