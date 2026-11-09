# 07_legacy.R -- the legacy pipe: NY Fed indicative / brokered history from checksummed local files.
# Every series name carries the "ind_" prefix. Loading warns; splice_indicative() is the only
# sanctioned way to join these rows to an official series, and it warns again and flags every row.

.excel_date <- function(x) if (inherits(x, "POSIXt")) as.Date(x) else as.Date(as.numeric(x), origin = "1899-12-30")

# read a sheet whose header is in `header_row`, keep the date + named value columns only
.read_block <- function(path, sheet, header_row, keep_pattern) {
  raw <- read_excel(path, sheet = sheet, col_names = FALSE, .name_repair = "minimal")
  hdr <- as.character(unlist(raw[header_row, ]))
  body <- raw[-(1:header_row), ]
  names(body) <- make.names(ifelse(is.na(hdr), "blank", hdr), unique = TRUE)   # syntactic, unique
  cols <- names(body)[str_detect(names(body), keep_pattern)]
  body %>% transmute(date = .excel_date(.data[[names(body)[1]]]), across(all_of(cols), ~ suppressWarnings(as.numeric(.x)))) %>%
    filter(!is.na(date))
}

build_legacy <- function(cal) {
  warn_indicative("legacy pipe (indicative repo rates/volumes, brokered fed funds, indicative SOFR averages)")
  src <- function(f) paste0("nyfed_static:", f)

  # 1. indicative TGCR / BGCR / SOFR: VWM Rates (bp, as is) and Volumes ($bn -> $mn)
  f1 <- "indicative_repo_2014_2018.xlsx"; p1 <- static_file(f1)
  nm <- c("Tri" = "ind_tgcr", "Broad" = "ind_bgcr", "Secured" = "ind_sofr")   # column names are make.names()'d
  rates <- .read_block(p1, "VWM Rates", 2, "^Tri|^Broad|^Secured") %>%
    pivot_longer(-date, names_to = "col", values_to = "value") %>%
    mutate(series = unname(nm[str_extract(col, "^Tri|^Broad|^Secured")]), stat = "rate", unit = "bp", source = src(f1))
  vols <- .read_block(p1, "Volumes", 2, "^Tri|^Broad|^Secured") %>%
    pivot_longer(-date, names_to = "col", values_to = "value") %>%
    mutate(series = unname(nm[str_extract(col, "^Tri|^Broad|^Secured")]), stat = "volume", value = value * 1000, unit = "usd_mn", source = src(f1))

  # 2. brokered fed funds percentiles (percent -> bp) and volume ($bn -> $mn)
  f2 <- "ff_volumes_2006_2016.xlsx"; p2 <- static_file(f2)
  raw2 <- as.data.frame(read_excel(p2, sheet = 1, col_names = FALSE, .name_repair = "minimal"))
  meta_series <- as.character(raw2[[9]]); meta_units <- as.character(raw2[[11]])   # metadata block to the right
  vol_unit <- meta_units[!is.na(meta_series) & meta_series == "Volume"]
  stopifnot(length(vol_unit) == 1, str_detect(str_to_lower(vol_unit), "billion"))
  ff <- .read_block(p2, 1, 1, "Percentile|Volume") %>%
    pivot_longer(-date, names_to = "col", values_to = "value") %>%
    # make.names() prefixes digit-led headers with "X": X1st.Percentile.Rate etc.
    mutate(stat = case_when(str_detect(col, "1st") ~ "p1", str_detect(col, "25th") ~ "p25", str_detect(col, "50th") ~ "p50",
                            str_detect(col, "75th") ~ "p75", str_detect(col, "99th") ~ "p99",
                            str_detect(col, "Volume") ~ "volume", TRUE ~ NA_character_),
           series = "ind_effr_brokered",
           value = if_else(stat == "volume", value * 1000, value * 100),
           unit = if_else(stat == "volume", "usd_mn", "bp"), source = src(f2))

  # 3. indicative SOFR averages (percent -> bp) and index (ratio, x1)
  f3 <- "indicative_sofr_avg_2018_2020.xlsx"; p3 <- static_file(f3)
  av <- .read_block(p3, "Data", 2, "Index|Average") %>%
    pivot_longer(-date, names_to = "col", values_to = "value") %>%
    mutate(stat = case_when(str_detect(col, "Index") ~ "index", str_detect(col, "180") ~ "avg180",
                            str_detect(col, "90") ~ "avg90", str_detect(col, "30") ~ "avg30", TRUE ~ NA_character_),
           series = "ind_sofr_averages",
           value = if_else(stat == "index", value, value * 100),
           unit = if_else(stat == "index", "ratio", "bp"), source = src(f3))

  out <- bind_rows(rates, vols, ff, av) %>% filter(!is.na(value)) %>% mutate(value = round(value, 8)) %>% select(all_of(LONG_COLS))
  out <- to_bdays(out, cal) %>% select(all_of(LONG_COLS)) %>% arrange(series, stat, date)
  for (s in unique(out$series)) log_series(s, "", out %>% filter(series == s), paste(unique(out$unit[out$series == s]), collapse = "/"))
  check_long(out)
}

# The only sanctioned join of indicative rows onto an official series. Returns the official rows
# plus the indicative rows renamed to the official series name, with source = "indicative:<orig>".
splice_indicative <- function(official, legacy, official_series, ind_series, stat = "rate") {
  warn_indicative(paste0("splicing ", ind_series, "/", stat, " onto ", official_series))
  off <- official %>% filter(series == official_series)
  ind <- legacy %>% filter(series == ind_series, stat == !!stat, date < min(off$date)) %>%
    mutate(series = official_series, source = paste0("indicative:", source))
  bind_rows(ind, off %>% mutate(source = paste0("official:", source))) %>% arrange(date, stat)
}
