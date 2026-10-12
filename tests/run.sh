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

# Session listing, against a throwaway config holding two sessions: one started
# in a scratch directory, one elsewhere. Only the first is listed by default.
script="$PWD/../skills/handoff-from/scripts/claude-handoff"
scratch="$(mktemp -d)"
mkdir -p "$scratch/config/projects/a" "$scratch/config/projects/b" "$scratch/work"
work="$(cd "$scratch/work" && pwd -P)"
sed "s|/work/app|$work|" fixtures/session.jsonl > "$scratch/config/projects/a/11111111-aaaa.jsonl"
cp fixtures/session.jsonl "$scratch/config/projects/b/22222222-bbbb.jsonl"

listing() { (cd "$work" && CLAUDE_CONFIG_DIR="$scratch/config" "$script" --list "$@" 2>&1); }
expect() { # name, condition result
  if [ "$2" = yes ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
here_only="$(listing)"
everywhere="$(listing --all)"
expect "lists sessions started in this directory" \
  "$(grep -q 11111111 <<<"$here_only" && grep -q 'Now add a test' <<<"$here_only" && echo yes)"
expect "leaves out sessions started elsewhere" \
  "$(grep -q 22222222 <<<"$here_only" || echo yes)"
expect "--all lists sessions from every directory" \
  "$(grep -q 11111111 <<<"$everywhere" && grep -q 22222222 <<<"$everywhere" && echo yes)"

# Whole pipeline with a stub claude on PATH, so no tokens are spent: the
# handoff call gets the digest, and its result lands in the handoffs folder.
mkdir -p "$scratch/bin"
cat > "$scratch/bin/claude" <<'STUB'
#!/bin/bash
cat > "$(dirname "$0")/input.txt"
echo '{"result":"STUB HANDOFF","usage":{"input_tokens":1,"output_tokens":1},"total_cost_usd":0}'
STUB
chmod +x "$scratch/bin/claude"
PATH="$scratch/bin:$PATH" CLAUDE_CONFIG_DIR="$scratch/config" "$script" 1111 --no-launch 2>/dev/null
expect "writes the handoff returned by the model" \
  "$(grep -qx 'STUB HANDOFF' "$scratch/config/handoffs/11111111-aaaa.md" && echo yes)"
expect "sends the digest and edited files to the model" \
  "$(grep -q 'USER: Now add a test' "$scratch/bin/input.txt" && grep -q "$work/auth.rb" "$scratch/bin/input.txt" && echo yes)"

# Shell wrapper routing, in bash and in zsh when present.
for sh in bash zsh; do
  command -v "$sh" >/dev/null || continue
  routed="$("$sh" -c '. "$1"; _claude_handoff_script=_show; _show() { printf "[%s]" "$@"; }
    claude --handoff-from abc; echo
    claude --model opus --handoff-from abc --effort high; echo
    claude --handoff-from --model opus; echo
    claude --handoff-from' _ "$PWD/../shell/handoff.bash")"
  expected='[--session=abc]
[--session=abc][--model][opus][--effort][high]
[--session=][--model][opus]
[--session=]'
  expect "wrapper routes arguments in $sh" "$([ "$routed" = "$expected" ] && echo yes)"
done

rm -r "$scratch"

exit $fail
