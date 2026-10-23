#!/usr/bin/env bash
# Test double for curl. Used only by tests/connect.tftest.hcl through the module's
# test-only curl_command variable. It never opens a network connection.
#
# Appends one record per call to $FAKE_CURL_CAPTURE: a "CALL" line, one "ARGV" line per
# argument, "ENV" lines for the three post-back variables and one "STDIN" line.
# Like curl with `-o <file> -w '%{http_code}'`, it writes the fake server body to the -o file
# and prints the HTTP status on stdout. $FAKE_CURL_HTTP_CODE sets the status (default 200, or
# 401 when $FAKE_CURL_EXIT is non-zero). Exits with $FAKE_CURL_EXIT (default 0).
set -u

capture="${FAKE_CURL_CAPTURE:?FAKE_CURL_CAPTURE must name the capture file}"
mkdir -p "$(dirname "$capture")"

stdin_line=""
if [ ! -t 0 ]; then
  IFS= read -r -t 1 stdin_line || true
fi

{
  echo "CALL"
  for arg in "$@"; do
    printf 'ARGV %s\n' "$arg"
  done
  printf 'ENV MC_CONNECT_TOKEN=%s\n' "${MC_CONNECT_TOKEN-}"
  printf 'ENV MC_URL=%s\n' "${MC_URL-}"
  printf 'ENV MC_BODY=%s\n' "${MC_BODY-}"
  printf 'STDIN %s\n' "$stdin_line"
} >> "$capture"

out_file=""
prev=""
for arg in "$@"; do
  [ "$prev" = "-o" ] && out_file="$arg"
  prev="$arg"
done

status="${FAKE_CURL_EXIT:-0}"
if [ "$status" != "0" ]; then
  code="${FAKE_CURL_HTTP_CODE:-401}"
  body='{"detail":"fake server: connect token rejected"}'
else
  code="${FAKE_CURL_HTTP_CODE:-200}"
  body="{\"detail\":\"fake server: HTTP $code\"}"
  case "$code" in 3??) body="{\"detail\":\"fake server: HTTP $code redirect\"}" ;; esac
fi
[ -n "$out_file" ] && printf '%s' "$body" > "$out_file"
printf '%s' "$code"
exit "$status"
