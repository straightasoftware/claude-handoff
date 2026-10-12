# Adds `claude --handoff-from <session-id>` to bash or zsh: a fresh session
# continuing from a digest of the old one. Every other invocation goes straight
# to the real claude. Source this file from your shell startup file.
# The script is found relative to this file, so source it from a clone of the
# repository rather than copying it elsewhere.
_claude_handoff_script="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../skills/handoff-from/scripts" && pwd)/claude-handoff"

# The word after --handoff-from is the session ID unless it is missing or a
# flag; then the script lists recent sessions to pick from.
claude() {
  local i=1 a next
  for a in "$@"; do
    if [ "$a" = "--handoff-from" ]; then
      next="${@:$((i + 1)):1}"
      case "$next" in
        "" | -*) "$_claude_handoff_script" --session= "${@:1:$((i - 1))}" "${@:$((i + 1))}" ;;
        *) "$_claude_handoff_script" "--session=$next" "${@:1:$((i - 1))}" "${@:$((i + 2))}" ;;
      esac
      return
    fi
    i=$((i + 1))
  done
  command claude "$@"
}
