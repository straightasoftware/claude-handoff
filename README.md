# claude-handoff

Continue from an earlier Claude Code session without resuming it.

```bash
claude --handoff-from <session-id>     # instead of: claude --resume <session-id>
```

or, inside Claude Code: `/handoff-from <session-id>`.

## Why

Claude Code caches the conversation so each turn re-reads it cheaply. The
cache expires (after 5 minutes or an hour, depending on the setup), so
coming back to a large session after a break re-sends its whole context at
the full cache-write price. If you run several sessions and return to them at
random times, that happens constantly.

This tool builds a short handoff from the old session's transcript instead,
and starts a fresh session from it:

1. A `jq` filter pulls out each of your prompts and Claude's final reply to
   it. Tool calls and tool output, which are most of a transcript, are
   dropped. This step uses no tokens.
2. It adds the files the session edited and the repository's current git
   state.
3. A separate one-shot `claude -p` call (Sonnet by default, with no tools and
   no project instructions loaded) turns that into a handoff note under
   `~/.claude/handoffs/`.
4. A new session starts in the old working directory and reads only the note.

## What it saves

Measured on one real session that had grown to 675k tokens of context on
Opus:

| | Resume | Handoff |
|---|---|---|
| Tokens to get going again | 675k, re-sent on Opus at cache-write price if the cache has expired | 43k read and 6k written, on Sonnet |
| Context every later turn re-reads | 675k and growing | the ~1,700-word note plus whatever the new work adds |
| Time | immediate | about a minute |

The first row is the saving you notice. The second is usually bigger over
time: every turn, including every tool call, re-reads the whole context. Even
from cache that costs something on every turn, and a session that started
small stays cheaper for as long as it runs.

How big the digest is relative to the session varies with how much of the work
happened in tool output. Across three large sessions (peak contexts of 675k
to 898k tokens) the digest of prompts and final replies came to 4–15% of the
peak context. These are a few measurements, not a guarantee. To measure
your own, run `handoff-report <old-session-id>` (in
`skills/handoff-from/scripts/`) after working in the new session for a while.
It reads the token counts recorded in the transcripts and shows the handoff
call, the new session, and what resuming would have cost for the same
requests: the old context written to the cache once, then re-read on every
later request.

## Install

Requires Claude Code, `bash` and `jq`, on macOS or Linux.

**The skill** (`/handoff-from` inside Claude Code), as a plugin:

```
/plugin marketplace add straightasoftware/claude-handoff
/plugin install handoff@claude-handoff
```

**The command-line flag** (`claude --handoff-from`). A plugin cannot change
your shell, so this part is a clone plus one line in your shell startup file
(`~/.zshrc`, `~/.bashrc` or `~/.bash_profile`):

```bash
git clone https://github.com/straightasoftware/claude-handoff ~/.claude-handoff
echo '. "$HOME/.claude-handoff/shell/handoff.bash"' >> ~/.zshrc
```

This defines a `claude` shell function that handles `--handoff-from` and
passes everything else to the real `claude` unchanged. `claude handoff-from <id>`, without the dashes, works too: the real `claude` would take `handoff-from` as the prompt and silently drop the ID. Other flags go to the
new session: `claude --model opus --handoff-from <id>`.

A unique prefix of the session ID is enough. Without an ID,
`claude --handoff-from` lists the recent sessions started in the current
directory, with the date and your last prompt in each, and asks which one to
continue:

```
 1  2026-10-12 15:04  5471f686  ~/dev
      One other gotcha - the session ID is not easy to find if the session h
 2  2026-10-12 14:59  dab96dd2  ~/dev
      After the 30 days, support is the route back. I thought we decided we
Hand off from which session?
```

That works after a crash or a reboot too, because it reads the transcripts on
disk rather than anything the session printed. `claude-handoff --list --all`
lists sessions from every directory.

## Options

| Variable | Default | Effect |
|---|---|---|
| `HANDOFF_MODEL` | `sonnet` | Model that writes the handoff. `haiku` costs less; `opus` summarises better. |
| `HANDOFF_MAX_BYTES` | `160000` (~40k tokens) | Digest budget. Over it, the first prompt (usually the brief) and the most recent exchanges are kept. |
| `CLAUDE_CONFIG_DIR` | `~/.claude` | Where transcripts are read and handoffs written. |

`claude-handoff <id> --no-launch` writes the handoff without starting a
session.

The listing does not print the session ID on every reply, which was the
first idea: that costs output tokens on every turn, and the reply that would
carry the ID is exactly what a crash loses.

## Limits

- The handoff is a model-written summary. The new session is told to check
  the claims it relies on against the repository.
- Anything that appeared only in tool output and was never mentioned in a
  reply (an exact error message, say) is not in the handoff. Re-running the
  command recovers it.
- The transcript format is Claude Code's internal format, not a documented
  interface. An update could change it; `tests/run.sh` checks the filter
  against a fixture.

## Alternatives considered

- **`claude --resume`** after the cache has expired re-sends the full context.
  That is the cost this avoids.
- **`/compact`** also re-reads the full context to summarise it, and its
  summary is less controlled than a written handoff.
- **Having Claude keep a handoff file updated as it works.** Every file write
  is a tool call, and each tool call re-reads the whole context, so updating
  every turn roughly doubles the cost of a large session.
- **Writing the handoff automatically after the session has been idle for a
  while, before the cache expires.** Claude Code has no idle trigger. The
  in-session scheduler fires at wall-clock times and would need re-arming
  every turn, which is itself a tool call over the full context. An external
  timer would need to inject a prompt from a different client, which likely
  misses the cache anyway.

## License

MIT
