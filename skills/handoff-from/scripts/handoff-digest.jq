# Digest of a Claude Code transcript: each real user prompt, plus the last
# assistant text before the next prompt. Tool calls and their output are
# dropped; they are most of a transcript and the replies summarise them.
# Run with jq -rs --argjson max <bytes>. Over budget, keeps the first prompt
# (usually the brief) and as many recent exchanges as fit.
def text: .message.content
  | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join("\n")) end;

[ .[] | select((.type == "user" or .type == "assistant") and (.isSidechain | not)) ]
| reduce .[] as $m ({out: [], last: null};
    if $m.type == "user" and ($m.isMeta | not) and (($m | text) | length > 0) then
      .out += (if .last then ["CLAUDE: " + .last] else [] end) + ["USER: " + ($m | text)]
      | .last = null
    elif $m.type == "assistant" and (($m | text) | length > 0) then .last = ($m | text)
    else . end)
| .out + (if .last then ["CLAUDE: " + .last] else [] end)
| if (map(length) | add // 0) <= $max then join("\n\n")
  else
    .[0] as $first
    | (.[1:] | reverse
       | reduce .[] as $e ({kept: [], size: ($first | length)};
           if .size + ($e | length) <= $max and .done != true
           then .kept = [$e] + .kept | .size += ($e | length)
           else .done = true end)
       | .kept) as $tail
    | ([$first, "[... earlier exchanges omitted to fit the digest budget ...]"] + $tail) | join("\n\n")
  end
