# 05_align.R -- attach quarterly series (GDP, potential GDP) to a set of dates.
#   method = "linear": linear interpolation between MID-QUARTER anchors (quarter start + 45 days),
#                      the default. Dates beyond the last anchor are NA unless extend = TRUE.
#   extend = TRUE    : actual GDP beyond its last anchor is extended at the growth rate of
#                      potential GDP (which has projections) and flagged `extended = TRUE`.
#                      OFF by default (decision D12, 2026-11-09): a casual call never returns
#                      provisional numbers; the user must ask for them.
#   method = "step"  : value of the quarter containing the date (as published, no invention); NA after
#                      the last day of the last published quarter (fixed 2026-11-09: it used to carry the
#                      last quarter forward indefinitely).
# Output: tibble(date, series, value, unit, method, extended). Never stored; call it in analysis.

mid_quarter <- function(qstart) as.Date(qstart) + 45

align_quarterly <- function(q, dates, series = c("ngdp", "ngdp_potential"),
                            method = c("linear", "step"), extend = FALSE, tail_from = "ngdp_potential") {
  method <- match.arg(method)
  dates <- sort(unique(as.Date(dates)))
  q <- q %>% filter(series %in% c(!!series, tail_from), !is.na(value)) %>% arrange(series, date)
  unit <- unique(q$unit); stopifnot(length(unit) == 1)

  one <- function(s) {
    d <- q %>% filter(series == s)
    if (method == "step") {
      idx <- findInterval(dates, d$date)
      last_day <- max(d$date) %m+% months(3) - 1          # last calendar day of the last published quarter
      v <- ifelse(idx >= 1 & dates <= last_day, d$value[pmax(idx, 1)], NA_real_)
      return(tibble(date = dates, series = s, value = v, unit = unit, method = "step", extended = FALSE))
    }
    anchors <- mid_quarter(d$date)
    v <- approx(anchors, d$value, xout = as.numeric(dates), rule = 1)$y   # NA outside anchors
    ext <- rep(FALSE, length(dates))
    beyond <- dates > max(anchors)
    if (extend && any(beyond) && s != tail_from && tail_from %in% q$series) {
      p <- q %>% filter(series == tail_from)
      pa <- mid_quarter(p$date)
      pot_at <- function(x) approx(pa, p$value, xout = as.numeric(x), rule = 1)$y
      last_v <- d$value[which.max(anchors)]; last_a <- max(anchors)
      g <- pot_at(dates[beyond]) / pot_at(last_a)
      v[beyond] <- last_v * g
      ext[beyond] <- !is.na(g)
    }
    tibble(date = dates, series = s, value = v, unit = unit, method = "linear", extended = ext)
  }
  bind_rows(lapply(series, one))
}
