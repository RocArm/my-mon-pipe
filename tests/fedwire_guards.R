# fedwire_guards.R -- proves the aux6 guards fire. Each case damages a copy of the latest cached raw files
# the way a page or file change could, and must be caught: either the parser stops ("aux6 BROKEN PIPE")
# or fedwire_checks() reports a failing check. Offline; sourced by run_tests.R, which defines ok().
fedwire_guard_cases <- function() {
  dir <- pipe_path("data", "raw", "frbservices")
  latest <- function(name, ext) tail(sort(list.files(dir, pattern = paste0("^", name, "_[0-9]{8}[.]", ext, "$"), full.names = TRUE)), 1)
  rd <- function(p) { x <- readChar(p, file.size(p), useBytes = TRUE); Encoding(x) <- "UTF-8"; x }
  raw <- list(txt_m = rd(latest("monthly", "txt")), txt_q = rd(latest("quarterly", "txt")),
              html_m = rd(latest("monthly_page", "html")), html_q = rd(latest("quarterly_page", "html")),
              html_a = rd(latest("annual_page", "html")))
  parse_all <- function(r) list(
    meta_m = fedwire_page_meta(r$html_m, "m"), meta_q = fedwire_page_meta(r$html_q, "q"), meta_a = fedwire_page_meta(r$html_a, "a"),
    txt_m = fedwire_parse_txt(r$txt_m, "m"), txt_q = fedwire_parse_txt(r$txt_q, "q"),
    html_m = fedwire_parse_html(r$html_m, "m"), html_q = fedwire_parse_html(r$html_q, "q"), html_a = fedwire_parse_html(r$html_a, "a"))
  # first / n-th data line of a text file, and a helper to rewrite one
  tlines <- function(x) strsplit(x, "\r?\n")[[1]]
  rows_of <- function(l) which(grepl("^\\s*[0-9]{4}\\s*:", l))
  edit_txt <- function(x, f) paste(f(tlines(x)), collapse = "\n")
  sub1 <- function(x, a, b) { stopifnot(grepl(a, x, fixed = TRUE)); sub(a, b, x, fixed = TRUE) }
  # a monthly text row with its fields; rebuild it with new fields
  rowf <- function(line) str_match(line, "^(\\s*[0-9]{4}\\s*:\\s*[A-Za-z0-9]+)\\s+(.*)$")
  set_fields <- function(line, fun) { m <- rowf(line); f <- strsplit(str_squish(m[, 3]), " ")[[1]]; paste(m[, 2], paste(fun(f), collapse = "   ")) }
  fmt <- function(v) formatC(v, format = "d", big.mark = ",")
  num <- function(s) as.numeric(gsub(",", "", s))

  cases <- list(
    "text header: unit changes to $ billions" = function(r) { r$txt_m <- sub1(r$txt_m, "($ millions)", "($ billions)"); r },
    "text header: a column is added" = function(r) { r$txt_q <- sub1(r$txt_q, "Quarter ", "Quarter    Business days "); r },
    "text footer: a methodology note changes" = function(r) { r$txt_m <- sub1(r$txt_m, "exclude non value transfers", "include non-value transfers"); r },
    "text row: an extra field" = function(r) { r$txt_m <- edit_txt(r$txt_m, function(l) { i <- rows_of(l)[1]; l[i] <- paste(l[i], "  123"); l }); r },
    "text row: a field missing" = function(r) { r$txt_m <- edit_txt(r$txt_m, function(l) { i <- rows_of(l)[5]; l[i] <- set_fields(l[i], function(f) f[-2]); l }); r },
    "text row: a month dropped" = function(r) { r$txt_m <- edit_txt(r$txt_m, function(l) l[-rows_of(l)[30]]); r },
    "text row: a month duplicated" = function(r) { r$txt_m <- edit_txt(r$txt_m, function(l) { i <- rows_of(l)[30]; append(l, l[i], i) }); r },
    "text row: unknown month label" = function(r) { r$txt_m <- edit_txt(r$txt_m, function(l) { i <- rows_of(l)[3]; l[i] <- sub(":\\s*[A-Za-z]+", ":Q3", l[i]); l }); r },
    "text row: a note line among the data" = function(r) { r$txt_m <- edit_txt(r$txt_m, function(l) append(l, "Revised figures below", rows_of(l)[10])); r },
    "text row: a number with a letter" = function(r) { r$txt_q <- edit_txt(r$txt_q, function(l) { i <- rows_of(l)[2]; l[i] <- set_fields(l[i], function(f) { f[1] <- "58,2O3,990"; f }); l }); r },
    "text: history truncated to 2010 on" = function(r) { r$txt_m <- edit_txt(r$txt_m, function(l) { i <- rows_of(l); l[-i[grepl("^\\s*200[0-9]", l[i])]] }); r },
    "text: count and value columns swapped in one row" = function(r) { r$txt_m <- edit_txt(r$txt_m, function(l) { i <- rows_of(l)[12]; l[i] <- set_fields(l[i], function(f) f[c(3, 2, 1, 4:length(f))]); l }); r },
    "text: one value typed wrong (digit dropped)" = function(r) { r$txt_m <- edit_txt(r$txt_m, function(l) { i <- rows_of(l)[40]; l[i] <- set_fields(l[i], function(f) { f[3] <- fmt(floor(num(f[3]) / 10)); f }); l }); r },
    "text: value column rescaled to $ billions" = function(r) { r$txt_q <- edit_txt(r$txt_q, function(l) { for (i in rows_of(l)) l[i] <- set_fields(l[i], function(f) { f[3] <- fmt(round(num(f[3]) / 1000)); f[7] <- fmt(round(num(f[7]) / 1000)); f }); l }); r },
    "text: business days off by one in a month" = function(r) { r$txt_m <- edit_txt(r$txt_m, function(l) { i <- rows_of(l)[20]; l[i] <- set_fields(l[i], function(f) { f[6] <- as.character(as.integer(f[6]) + 1); f }); l }); r },
    "text: stale file (latest month missing, page updated)" = function(r) { r$txt_m <- edit_txt(r$txt_m, function(l) l[-rows_of(l)[1]]); r },
    "page: the text-file link disappears" = function(r) { r$html_m <- gsub("funds-ascii.txt", "funds-ascii.pdf", r$html_m, fixed = TRUE); r },
    "page: a second text-file link" = function(r) { r$html_q <- sub1(r$html_q, "<table", "<a href=\"https://www.frbservices.org/wp-content/uploads/old-quarterly.txt\">old</a><table"); r },
    "page: a second table" = function(r) { r$html_a <- sub1(r$html_a, "<table", "<table><tr><td>x</td></tr></table><table"); r },
    "page: title changes" = function(r) { r$html_a <- sub("(<title>[^<]*)Annual Statistics", "\\1Annual Data", r$html_a); r },
    "page: no 'Last updated' line" = function(r) { r$html_m <- gsub("Last updated on", "Updated", r$html_m, fixed = TRUE); r },
    "page: column header reworded" = function(r) { r$html_a <- sub1(r$html_a, "Average value per transfer", "Mean value per transfer"); r },
    "page: notes under the table change" = function(r) { r$html_q <- sub1(r$html_q, "were revised on July 26, 2016", "were revised on July 26, 2016 and March 3, 2026"); r },
    "page: annual table loses its first year" = function(r) { r$html_a <- sub("<tr>(?:(?!<tr>).)*?>1987</th>.*?</tr>", "", r$html_a, perl = TRUE); r },
    "page: annual count typed wrong" = function(r) { r$html_a <- sub1(r$html_a, "209,916,835", "209,916,853"); r }
  )
  base <- parse_all(raw)
  imap_dfr(cases, function(f, nm) {
    r <- f(raw)
    res <- tryCatch({ p <- parse_all(r); chk <- fedwire_checks(p, cal, reg)
                      if (all(chk$pass)) "NOT CAUGHT" else paste("check:", paste(chk$check[!chk$pass], collapse = ", ")) },
                    error = function(e) paste("stop:", sub("^aux6 BROKEN PIPE: ", "", conditionMessage(e))))
    tibble(case = nm, caught = res != "NOT CAUGHT" && (startsWith(res, "check:") || grepl("BROKEN PIPE|^stop:", res)), how = res)
  }) %>% mutate(baseline_clean = all(fedwire_checks(base, cal, reg)$pass))
}
