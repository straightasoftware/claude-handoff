#!/bin/bash
# Checks the transcript digest filter against a fixture transcript.
set -euo pipefail
cd "$(dirname "$0")"
jq_filter=../skills/handoff-from/scripts/handoff-digest.jq
fail=0

check() { # name, max bytes, expected file
  if diff -u "$3" <(jq -rs --argjson max "$2" -f "$jq_filter" fixtures/session.jsonl); then
    echo "ok   $1"
  else
    echo "FAIL $1"; fail=1
  fi
}

check "keeps prompts and final replies only" 100000 fixtures/expected.txt
# 60 bytes fits the first prompt and the last reply but not the exchange between.
check "over budget keeps first prompt and latest exchanges" 60 fixtures/expected-trimmed.txt
exit $fail
