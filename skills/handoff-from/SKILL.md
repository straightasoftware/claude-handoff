---
name: handoff-from
description: Continue work from an earlier Claude Code session without resuming it, by generating a handoff from that session's transcript. Use when the user says /handoff-from <session-id>, or asks to pick up, continue or hand off from another session by ID.
---

# Handoff from another session

Resuming a large session after its prompt cache expires re-sends its whole
context. This builds a short handoff from a digest of that session (user
prompts and final replies, files edited, git state) in a separate cheap call,
so only the handoff enters this session.

1. Run, with the session ID (a unique prefix is enough) from the arguments:

   ```bash
   "${CLAUDE_SKILL_DIR}/scripts/claude-handoff" <session-id> --no-launch
   ```

   It takes about a minute and prints the path of the handoff it wrote, under
   `~/.claude/handoffs/`. If no ID was given or it matches several transcripts,
   ask the user which session they mean.

2. Read the handoff file. Do not read the old transcript itself; that is the
   cost this avoids.

3. The handoff names the old session's working directory. If it differs from
   the current one, say so before touching files.

4. Check the claims that matter for the next step against the repository (git
   state, files named), since the handoff is a summary written by another
   model. Then summarise where things stand in a few lines and wait for the
   user.
