#!/bin/sh
# Dependency-free stats dashboard generator for the Snowflake StartOS package.
# Uses only busybox applets already present in the alpine base image:
# sh, awk, grep, sed, date, mkdir, sleep, tail, wc, cut.
set -eu

DATA_DIR="${DATA_DIR:-/data}"
LOG_FILE="${LOG_FILE:-$DATA_DIR/snowflake.log}"
WWW_DIR="${WWW_DIR:-/www}"
HTML_FILE="$WWW_DIR/index.html"
INTERVAL="${DASHBOARD_INTERVAL:-300}"

mkdir -p "$WWW_DIR"

esc() {
  # Minimal HTML-escape for values we interpolate.
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

fmt_gb() {
  # $1 = kilobytes -> "X.X MB" below 1 GB, "X.XX GB" at/above 1 GB.
  # (Name kept as fmt_gb since every call site already uses it; only the
  # unit shown adapts to the size.)
  awk -v kb="$1" 'BEGIN {
    if (kb >= 1048576) printf "%.2f GB", kb/1048576
    else printf "%.1f MB", kb/1024
  }'
}

trend_html() {
  # $1 = current-window kb, $2 = equivalent-length prior-window kb.
  # Emits a small up/down indicator, or nothing if there's no prior-window
  # data yet to compare against (e.g. the package was only installed today).
  awk -v cur="$1" -v prev="$2" 'BEGIN {
    if (prev <= 0) { printf ""; exit }
    pct = ((cur - prev) / prev) * 100
    if (pct < 0) { cls = "trend-down"; arrow = "&#9660;"; pct = -pct }
    else { cls = "trend-up"; arrow = "&#9650;" }
    printf " <span class=\"trend %s\">%s %d%%</span>", cls, arrow, (pct + 0.5)
  }'
}

now_epoch() { date -u +%s; }

line_epoch() {
  # $1="YYYY/MM/DD" $2="HH:MM:SS" -> epoch seconds (UTC), or empty on failure
  date -u -D "%Y/%m/%d %H:%M:%S" -d "$1 $2" +%s 2>/dev/null || true
}

generate() {
  tmp="$WWW_DIR/.index.html.tmp"
  now="$(now_epoch)"
  today_start=$(( now - (now % 86400) ))
  week_start=$(( now - 7*86400 ))
  month_start=$(( now - 30*86400 ))

  # Comparison windows for the up/down trend indicators: each is the same
  # length as its current window, immediately preceding it. "Yesterday" is
  # capped at the same elapsed time-of-day as today so a partial today isn't
  # unfairly compared against a full day.
  today_elapsed=$(( now - today_start ))
  yesterday_start=$(( today_start - 86400 ))
  yesterday_end=$(( yesterday_start + today_elapsed ))
  prev_week_start=$(( week_start - 7*86400 ))
  prev_week_end=$week_start
  prev_month_start=$(( month_start - 30*86400 ))
  prev_month_end=$month_start

  nat_type="unknown"
  nat_ts=""
  proxy_start_ts=""

  today_conn=0; today_down=0; today_up=0
  week_conn=0;  week_down=0;  week_up=0
  month_conn=0; month_down=0; month_up=0
  total_conn=0; total_down=0; total_up=0
  prev_today_down=0; prev_today_up=0
  prev_week_down=0;  prev_week_up=0
  prev_month_down=0; prev_month_up=0
  sample_count=0
  latest_hour_conn="-"
  recent_rows=""
  bar_data=""
  max_kb=0

  if [ -f "$LOG_FILE" ]; then
    nat_line="$(grep -a 'NAT type:' "$LOG_FILE" 2>/dev/null | tail -n 1 || true)"
    if [ -n "$nat_line" ]; then
      nat_ts="$(printf '%s\n' "$nat_line" | awk '{print $1" "$2}')"
      nat_type="$(printf '%s\n' "$nat_line" | sed -n 's/.*NAT type: *//p' | tr -d '\r\n')"
    fi

    start_line="$(grep -a 'Proxy starting' "$LOG_FILE" 2>/dev/null | tail -n 1 || true)"
    if [ -n "$start_line" ]; then
      proxy_start_ts="$(printf '%s\n' "$start_line" | awk '{print $1" "$2}')"
    fi

    # Dedupe identical consecutive summary lines (the proxy logs each hourly
    # summary through two loggers, so it commonly appears twice back-to-back).
    summary_lines="$(grep -a 'completed successful connections' "$LOG_FILE" 2>/dev/null | awk '!seen[$0]++' || true)"

    if [ -n "$summary_lines" ]; then
      # Emit "epoch conn down up" per line, most recent last.
      parsed="$(printf '%s\n' "$summary_lines" | awk '
        {
          conn=$9; down=$16; up=$21;
          print $1, $2, conn, down, up
        }')"

      total_rows=$(printf '%s\n' "$parsed" | grep -c . || true)
      keep_from=$((total_rows - 24))

      # Walk lines, converting date+time to epoch (needs the `date` binary,
      # so this loop runs in the shell rather than inside awk).
      table_rows=""
      bar_data=""
      row_n=0
      # shellcheck disable=SC2094
      exec 9<<EOF_PARSED
$parsed
EOF_PARSED
      while IFS=' ' read -r d t conn down up <&9; do
        [ -z "$d" ] && continue
        ep="$(line_epoch "$d" "$t")"
        [ -z "$ep" ] && continue

        sample_count=$((sample_count + 1))
        total_conn=$((total_conn + conn))
        total_down=$((total_down + down))
        total_up=$((total_up + up))

        if [ "$ep" -ge "$month_start" ]; then
          month_conn=$((month_conn + conn)); month_down=$((month_down + down)); month_up=$((month_up + up))
        fi
        if [ "$ep" -ge "$week_start" ]; then
          week_conn=$((week_conn + conn)); week_down=$((week_down + down)); week_up=$((week_up + up))
        fi
        if [ "$ep" -ge "$today_start" ]; then
          today_conn=$((today_conn + conn)); today_down=$((today_down + down)); today_up=$((today_up + up))
        fi

        if [ "$ep" -ge "$prev_month_start" ] && [ "$ep" -lt "$prev_month_end" ]; then
          prev_month_down=$((prev_month_down + down)); prev_month_up=$((prev_month_up + up))
        fi
        if [ "$ep" -ge "$prev_week_start" ] && [ "$ep" -lt "$prev_week_end" ]; then
          prev_week_down=$((prev_week_down + down)); prev_week_up=$((prev_week_up + up))
        fi
        if [ "$ep" -ge "$yesterday_start" ] && [ "$ep" -lt "$yesterday_end" ]; then
          prev_today_down=$((prev_today_down + down)); prev_today_up=$((prev_today_up + up))
        fi

        latest_hour_conn="$conn"
        row_n=$((row_n + 1))
        # Only build table/chart HTML for the last 24 rows -- avoids unbounded
        # string growth (and O(n^2) concatenation) once the log spans months.
        if [ "$row_n" -gt "$keep_from" ]; then
          row_html="<tr><td>$(esc "$d $t")</td><td>$(esc "$conn")</td><td>$(fmt_gb "$down")</td><td>$(fmt_gb "$up")</td></tr>"
          table_rows="$table_rows$row_html"
          bar_data="$bar_data$t|$((down + up))
"
        fi
      done
      exec 9<&-

      recent_rows="$table_rows"
    fi
  fi

  bar_html=""
  if [ -n "$bar_data" ]; then
    max_kb=$(printf '%s\n' "$bar_data" | awk -F'|' 'NF==2 && $2>max { max=$2 } END { print max+0 }')
    # shellcheck disable=SC2094
    exec 8<<EOF_BARS
$bar_data
EOF_BARS
    while IFS='|' read -r blabel bkb <&8; do
      [ -z "$blabel" ] && continue
      pct=$(awk -v kb="$bkb" -v max="$max_kb" 'BEGIN { p = (max > 0) ? (kb * 100 / max) : 0; if (p < 3) p = 3; printf "%d", p }')
      bar_html="$bar_html<div class=\"bar\" style=\"height:${pct}%\" title=\"$(esc "$blabel UTC"): $(fmt_gb "$bkb")\"></div>"
    done
    exec 8<&-
  fi

  case "$(printf '%s' "$nat_type" | tr '[:upper:]' '[:lower:]')" in
    unrestricted) nat_class="nat-good" ;;
    restricted) nat_class="nat-warn" ;;
    *) nat_class="" ;;
  esac

  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  {
    printf '%s\n' '<!doctype html><html lang="en"><head><meta charset="utf-8">'
    printf '%s\n' '<meta name="viewport" content="width=device-width, initial-scale=1">'
    # Auto-reload every $INTERVAL seconds. The query string changes each time
    # (it's the render timestamp), so each reload is a distinct URL and the
    # browser can't just replay a cached copy of this exact response.
    printf '<meta http-equiv="refresh" content="%s;url=/?t=%s">\n' "$INTERVAL" "$now"
    printf '%s\n' '<link rel="icon" type="image/svg+xml" href="data:image/svg+xml,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 24 24%27%3E%3Crect width=%2724%27 height=%2724%27 rx=%275%27 fill=%27%233c194f%27/%3E%3Cg stroke=%27white%27 stroke-width=%271.5%27 stroke-linecap=%27round%27%3E%3Cline x1=%2720.23%27 y1=%2716.75%27 x2=%273.77%27 y2=%277.25%27/%3E%3Cline x1=%2712%27 y1=%2721.5%27 x2=%2712%27 y2=%272.5%27/%3E%3Cline x1=%273.77%27 y1=%2716.75%27 x2=%2720.23%27 y2=%277.25%27/%3E%3Cline x1=%2717.2%27 y1=%2715%27 x2=%2720.57%27 y2=%2711.25%27/%3E%3Cline x1=%2717.2%27 y1=%2715%27 x2=%2715.63%27 y2=%2719.79%27/%3E%3Cline x1=%2712%27 y1=%2718%27 x2=%2716.93%27 y2=%2719.04%27/%3E%3Cline x1=%2712%27 y1=%2718%27 x2=%277.07%27 y2=%2719.04%27/%3E%3Cline x1=%276.8%27 y1=%2715%27 x2=%278.37%27 y2=%2719.79%27/%3E%3Cline x1=%276.8%27 y1=%2715%27 x2=%273.43%27 y2=%2711.25%27/%3E%3Cline x1=%276.8%27 y1=%279%27 x2=%273.43%27 y2=%2712.75%27/%3E%3Cline x1=%276.8%27 y1=%279%27 x2=%278.37%27 y2=%274.21%27/%3E%3Cline x1=%2712%27 y1=%276%27 x2=%277.07%27 y2=%274.96%27/%3E%3Cline x1=%2712%27 y1=%276%27 x2=%2716.93%27 y2=%274.96%27/%3E%3Cline x1=%2717.2%27 y1=%279%27 x2=%2715.63%27 y2=%274.21%27/%3E%3Cline x1=%2717.2%27 y1=%279%27 x2=%2720.57%27 y2=%2712.75%27/%3E%3C/g%3E%3C/svg%3E">'
    printf '%s\n' '<title>Snowflake Proxy Stats</title><style>'
    cat <<'CSS'
:root{color-scheme:light dark;--bg:#f9f9f7;--card:#ffffff;--text:#0b0b0b;--muted:#6b6a66;--border:rgba(0,0,0,.1);--good:#1a7f37;--warn:#9a6700;}
@media (prefers-color-scheme:dark){:root{--bg:#0d0d0d;--card:#1a1a19;--text:#fff;--muted:#c3c2b7;--border:rgba(255,255,255,.12);}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,"Segoe UI",sans-serif}
.container{max-width:960px;margin:0 auto;padding:28px 18px 50px}
h1{font-size:20px;margin:0 0 4px;display:flex;align-items:center;gap:8px}.meta{color:var(--muted);font-size:12px;margin-bottom:20px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-bottom:28px}
.tile{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:14px 16px}
.label{font-size:12px;color:var(--muted);margin-bottom:6px}.value{font-size:22px;font-weight:600}
.sub{font-size:11px;color:var(--muted);margin-top:4px}
.nat-good{color:var(--good)}.nat-warn{color:var(--warn)}
.trend{font-size:12px;font-weight:600}.trend-up{color:var(--good)}.trend-down{color:var(--warn)}
table{width:100%;border-collapse:collapse;font-size:12px}
th,td{text-align:left;padding:6px 8px;border-bottom:1px solid var(--border)}
th{color:var(--muted);font-weight:600}
h2{font-size:14px;margin:24px 0 8px}.peak{color:var(--muted);font-weight:400;font-size:12px}
.bar-chart{display:flex;align-items:flex-end;gap:3px;height:100px;padding:8px;background:var(--card);border:1px solid var(--border);border-radius:10px}
.bar{flex:1 1 auto;min-width:4px;background:var(--good);border-radius:2px 2px 0 0;transition:background .15s}
.bar:hover{background:#2ea043}
footer{margin-top:20px;color:var(--muted);font-size:11px}
CSS
    printf '%s\n' '</style></head><body><div class="container">'
    printf '%s\n' '<h1><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" aria-hidden="true"><line x1="20.23" y1="16.75" x2="3.77" y2="7.25"/><line x1="12" y1="21.5" x2="12" y2="2.5"/><line x1="3.77" y1="16.75" x2="20.23" y2="7.25"/><line x1="17.2" y1="15" x2="20.57" y2="11.25"/><line x1="17.2" y1="15" x2="15.63" y2="19.79"/><line x1="12" y1="18" x2="16.93" y2="19.04"/><line x1="12" y1="18" x2="7.07" y2="19.04"/><line x1="6.8" y1="15" x2="8.37" y2="19.79"/><line x1="6.8" y1="15" x2="3.43" y2="11.25"/><line x1="6.8" y1="9" x2="3.43" y2="12.75"/><line x1="6.8" y1="9" x2="8.37" y2="4.21"/><line x1="12" y1="6" x2="7.07" y2="4.96"/><line x1="12" y1="6" x2="16.93" y2="4.96"/><line x1="17.2" y1="9" x2="15.63" y2="4.21"/><line x1="17.2" y1="9" x2="20.57" y2="12.75"/></svg>Snowflake Proxy Stats</h1>'
    printf '<div class="meta">Generated %s &middot; Snowflake Dashboard powered by ruxal</div>\n' "$(esc "$generated_at")"

    printf '<div class="grid">'
    printf '<div class="tile"><div class="label">NAT Type</div><div class="value %s">%s</div>%s</div>' \
      "$nat_class" "$(esc "$nat_type")" \
      "$( [ -n "$nat_ts" ] && printf '<div class="sub">as of %s UTC</div>' "$(esc "$nat_ts")" || true )"
    printf '<div class="tile"><div class="label">Bandwidth (today)</div><div class="value">%s%s</div><div class="sub">%s connections</div></div>' \
      "$(fmt_gb $((today_down + today_up)))" "$(trend_html $((today_down + today_up)) $((prev_today_down + prev_today_up)))" "$today_conn"
    printf '<div class="tile"><div class="label">Bandwidth (7 days)</div><div class="value">%s%s</div><div class="sub">%s connections</div></div>' \
      "$(fmt_gb $((week_down + week_up)))" "$(trend_html $((week_down + week_up)) $((prev_week_down + prev_week_up)))" "$week_conn"
    printf '<div class="tile"><div class="label">Bandwidth (30 days)</div><div class="value">%s%s</div><div class="sub">%s connections</div></div>' \
      "$(fmt_gb $((month_down + month_up)))" "$(trend_html $((month_down + month_up)) $((prev_month_down + prev_month_up)))" "$month_conn"
    printf '<div class="tile"><div class="label">Bandwidth (all-time)</div><div class="value">%s</div><div class="sub">%s connections</div></div>' \
      "$(fmt_gb $((total_down + total_up)))" "$total_conn"
    printf '<div class="tile"><div class="label">Connections (latest hour)</div><div class="value">%s</div></div>' "$latest_hour_conn"
    printf '<div class="tile"><div class="label">Hourly summaries logged</div><div class="value">%s</div></div>' "$sample_count"
    if [ -n "$proxy_start_ts" ]; then
      printf '<div class="tile"><div class="label">Proxy last started</div><div class="value" style="font-size:15px">%s</div><div class="sub">UTC</div></div>' "$(esc "$proxy_start_ts")"
    fi
    printf '</div>'

    # The chart/table below only ever show the most recent 24 hourly
    # summaries (see keep_from above), even though sample_count keeps a
    # lifetime total -- cap what the heading claims to match what's shown.
    shown_hours=$sample_count
    if [ "$shown_hours" -gt 24 ]; then
      shown_hours=24
    fi

    if [ -n "$bar_html" ]; then
      printf '<h2>Bandwidth, last %s hours <span class="peak">(peak: %s)</span></h2>' "$shown_hours" "$(fmt_gb "$max_kb")"
      printf '<div class="bar-chart">%s</div>' "$bar_html"
    else
      printf '<h2>Bandwidth, last %s hours</h2>' "$shown_hours"
      printf '<p class="sub">No hourly summaries logged yet.</p>'
    fi

    printf '<h2>Recent hourly activity</h2>'
    if [ -n "$recent_rows" ]; then
      printf '<table><thead><tr><th>Hour ending (UTC)</th><th>Connections</th><th>Down</th><th>Up</th></tr></thead><tbody>%s</tbody></table>' "$recent_rows"
    else
      printf '<p class="sub">No hourly summaries logged yet.</p>'
    fi

    printf '<footer>%s hourly summaries parsed from %s.</footer>' "$sample_count" "$(esc "$LOG_FILE")"
    printf '</div></body></html>'
  } > "$tmp"

  mv "$tmp" "$HTML_FILE"
}

mkdir -p "$DATA_DIR"

# Initial render so the page isn't empty while we wait for the first interval.
generate || true

# Background loop: regenerate the dashboard periodically for as long as this
# process lives.
( while true; do
    sleep "$INTERVAL"
    generate || true
  done ) &
DASH_PID=$!

# Serve the generated dashboard on port 80 (the port declared for the "ui"
# interface in interfaces.ts).
busybox-extras httpd -f -p 80 -h "$WWW_DIR" &
HTTPD_PID=$!

# Run the actual proxy, teeing its output to both stdout (so it still shows up
# live in StartOS's Logs tab, same as before) and to a file on the data
# volume, which generate() reads to build the dashboard. A named pipe is used
# here instead of a plain `snowflake-proxy | tee` pipeline so that $! captures
# snowflake-proxy's own PID rather than tee's -- a plain pipeline backgrounds
# both commands but only exposes the PID of the *last* one, which would make
# the crash-detection loop below watch the wrong process.
PROXY_FIFO="/tmp/snowflake-proxy.fifo"
rm -f "$PROXY_FIFO"
mkfifo "$PROXY_FIFO"
tee -a "$LOG_FILE" < "$PROXY_FIFO" &
TEE_PID=$!
snowflake-proxy -log /dev/stdout > "$PROXY_FIFO" &
PROXY_PID=$!

term() {
  kill "$PROXY_PID" "$TEE_PID" "$HTTPD_PID" "$DASH_PID" 2>/dev/null || true
  wait 2>/dev/null || true
  rm -f "$PROXY_FIFO"
  exit 0
}
trap term TERM INT

# If any of these dies, tear the whole thing down so StartOS notices (via the
# daemon's health check) and restarts it.
while true; do
  kill -0 "$PROXY_PID" 2>/dev/null || { echo "snowflake-proxy exited, stopping" >&2; term; }
  kill -0 "$TEE_PID" 2>/dev/null || { echo "log writer exited, stopping" >&2; term; }
  kill -0 "$HTTPD_PID" 2>/dev/null || { echo "dashboard httpd exited, stopping" >&2; term; }
  kill -0 "$DASH_PID" 2>/dev/null || { echo "dashboard refresh loop exited, stopping" >&2; term; }
  sleep 5
done
