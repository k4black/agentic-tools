# Global Agent Rules

## Project orientation docs

- When starting work in a project, read (when present): `README.md`, the agent
  instructions (`CLAUDE.md`/`AGENTS.md`, incl. its Terminology section), and
  `TODO.md` / `PROGRESS.md` — before exploring the code.
- Keep those files updated as you work: a new service/module/command gets described
  in the README, new domain terms go to the AGENTS.md Terminology section,
  finished/discovered work is
  reflected in `TODO.md`/`PROGRESS.md`. Update in place as part of the change, not
  as a separate chore to ask about.
- If you feel that some skill is not up to date or miss some important context - 
  suggest user to update it.

## Git

- Use Conventional Commits 1.0.0: `<type>[optional scope]: <description>` (e.g. `feat(lang): add Polish language`).
- Keep the first line ≤ 72 characters; no long commit bodie, for complex features short bulletpoints.
- Never add AI-attribution strings to commits or PRs: no `Co-Authored-By: Claude/Codex/...`, no "Generated with ..." footers.
- Commit only when explicitly asked, or when the active workflow/skill inherently requires commits (e.g. babysit-pr, critique-loop).

