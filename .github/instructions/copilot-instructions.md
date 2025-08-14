# Copilot – Repository Instructions (infraflux)

## Mission

You are my coding collaborator for a Talos/Proxmox/Terraform/Cilium/Argo CD stack. Follow the project task tree precisely. Never skip the “research → plan → implement → verify → document” loop.

## Research discipline (MANDATORY before every task/subtask)

- Query **context7** and **deepwiki** via MCP first. Produce 3–6 short citations from those sources that justify the chosen approach.
- Summarize key constraints and common pitfalls discovered.
- Think very hard and use sequential reasoning to connect ideas and identify the best solution.
- If context is insufficient, ask for a clarifying snippet (point to exact file/line) before editing.

## Coding contract

- Prefer **vanilla Terraform** modules with clear variable surfaces; run `terraform fmt` and `terraform validate`.
- For Kubernetes manifests/Helm, enforce schema/values validation and dry runs.
- Always add/refresh tests (unit or policy), and update docs in `docs/`.
- Commit messages: Conventional Commits.
- Output a **checklist** of verifications you performed and also update any relevant documentation and diagrams and roadmap.

## Security & quality guardrails

- when running command in the terminal run each command seperatly to avoid crashing terminal sessions.
- Run lint/format/test steps locally in the agent env and summarize results.
- Propose remediations for any warnings; never ignore failing checks.
- NEVER include secrets in code or comments. Use External Secrets (1Password SDK) references only.

## Communication

- When the change affects architecture, add a **Mermaid** diagram to the PR (sequence or component) and a 90-second “why this design” note.
- Keep responses concise; prefer bulletproof steps over prose.

## Tools you must use

- MCP servers: `context7` and `deepwiki` (read-only). Start by: search → fetch → cite.
- GitHub MCP (read-only to this repo).
