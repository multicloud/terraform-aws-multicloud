#!/usr/bin/env bash
# Review Focus 5: a failed post-back must fail the apply, show the server message and the
# fallback command, and never show the connect token.
# Run from anywhere: tests/check_post_failure.sh (needs `tofu init -backend=false` done once).
set -u

cd "$(dirname "$0")/.." || exit 2
fail=0

check() { # name, required text, token
  local name="$1" required="$2" token="$3" out status
  out="$(tofu test -no-color -test-directory=tests/failure -filter="tests/failure/${name}.tftest.hcl" 2>&1)"
  status=$?
  out="$(tr '\n' ' ' <<<"$out")" # tofu wraps long lines; join them before grep
  if [ "$status" -eq 0 ]; then
    echo "FAIL ${name}: apply succeeded, expected a failure"; fail=1
  fi
  if ! grep -q "mctl cloud-account connect 42 --from-terraform-output" <<<"$out"; then
    echo "FAIL ${name}: the fallback command is missing"; fail=1
  fi
  if [ -n "$required" ] && ! grep -q "$required" <<<"$out"; then
    echo "FAIL ${name}: missing '${required}'"; fail=1
  fi
  if grep -q "$token" <<<"$out"; then
    echo "FAIL ${name}: the output contains the connect token"; fail=1
  fi
  [ "$fail" -eq 0 ] && echo "ok ${name}"
}

check post_rejected "fake server: connect token rejected" "tok-secret-DDDD4444"
check no_curl "command not found" "tok-secret-EEEE5555"
check redirect_302 "fake server: HTTP 302 redirect" "tok-secret-FFFF6666"
exit "$fail"
