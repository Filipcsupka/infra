# Copilot Instructions — infra (khtz GitOps)

## Context first (always)
Before answering any infra/cluster/deploy question, load context. The ops-brain vault lives OUTSIDE this workspace — read it via terminal:
- `cat ~/Documents/ops-brain/AGENTS.md` — canonical agent rules (context routing + execution policy)
- `cat ~/Documents/ops-brain/personal-infra/_context.md` and `cat ~/Documents/ops-brain/personal-infra/clusters/khtz.md`
- Repo-local: `AGENTS.md`, `CLAUDE.md`, `README.md`
Answer only after loading matching notes; say which notes you used.

## Execution policy
- Read-only diagnostics (kubectl get|describe|logs|events|top, helm list|get|status|template, argocd app get|list|diff, git status|log|diff, curl/dig) — run immediately, no permission questions, chain fast.
- State changes (kubectl apply/patch/delete/scale/restart, helm install/upgrade/rollback, argocd sync, terraform/ansible, secrets, git push) — show the exact command/manifest diff and WAIT for explicit user approval.
- GitOps-only cluster: ALL khtz changes via commits to this repo → ArgoCD. Never kubectl apply directly. terraform/ansible run via GitHub Actions only.
