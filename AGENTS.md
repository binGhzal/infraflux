# 🤖 InfraFlux – Codex Agent Guidelines

This file defines how AI coding agents should contribute to the InfraFlux repository.

---

## 📌 Scope

**The agent is responsible for:**

- Writing, refactoring, and organizing code and manifests in this repository.
- Maintaining consistency with the defined **repo structure** and **project vision** in `README.md`.
- Producing self-contained, testable deliverables.
- Generating **documentation for any code or manifests it creates**.

**The agent is NOT responsible for:**

- Running deployments or applying manifests to real infrastructure.
- Managing credentials, cloud accounts, or secrets.
- Making architectural changes without explicit instruction.

---

## 📂 Repo Rules

1. **Keep changes isolated** to the intended scope.
2. **Match directory purposes** exactly as described in `README.md`.
3. **Use declarative configs** wherever possible (YAML > imperative scripts).
4. **Follow naming conventions**:
   - Filenames lowercase with hyphens (`my-file.yaml`).
   - Resource names follow Kubernetes naming rules.
5. **Document non-obvious code** in comments and/or `.md` files.

---

## 🛠️ Coding Standards

- **Languages**:
  - CLI: Go (preferred) or Python (Typer/Click).
  - Infrastructure templates: YAML (CAPI, Talos, HelmReleases, Flux, Crossplane).
  - Scripts: Bash only for glue tasks (minimal use).
- **Indentation**:
  - YAML: 2 spaces.
  - Go/Python: idiomatic formatting (`go fmt`, `black`).
- **Kubernetes manifests**:
  - Grouped logically by kind and purpose.
  - Avoid inline secrets—use SOPS-encrypted files under `/sops/`.

---

## 📜 Task Types

When working, the agent may be asked to:

- Create new CAPI + Talos templates for a provider.
- Add a new recipe (Flux Kustomization/HelmRelease).
- Modify the CLI (`infraflux`) to support a new flag or workflow.
- Update documentation for new features.
- Add Crossplane compositions for a new cloud resource type.

---

## 🔄 Workflow for Agent Contributions

1. **Understand the task**:
   - Read `README.md` for context.
   - Identify where in the repo the change belongs.
2. **Create/update files** in the correct directory.
3. **Ensure syntax validity**:
   - `kubectl apply --dry-run=client` for Kubernetes YAML.
   - `go build` or `python -m py_compile` for CLI code.
4. **Document changes**:
   - Update or create `*.md` files as needed.
   - Add comments for YAML that requires explanation.
5. **Output changes as a diff or full file content** in Markdown code blocks.

---

## ✅ Definition of Done

A task is complete when:

- The deliverable matches the request exactly.
- Code or manifests pass syntax checks.
- Files are placed in the correct repo location.
- Documentation is updated.
- No deployment or execution has been attempted.

---

## 📣 Final Note

InfraFlux aims for **automation, portability, and clarity**.
All code should be **self-explanatory** and **production-grade**, even in a homelab context.
