# AGENTS.md

Tento subor je kanonicky kontext pre AI asistenta pracujuceho na repo `infra`.
Ak je nieco v konflikte medzi tymto suborom a starsim obsahom inde v projekte, preferuj tento subor.

## Context Protocol (run FIRST, before answering any issue)

1. Load context BEFORE replying: this file + `CLAUDE.md` + `README.md`, then ops-brain vault:
   - `~/Documents/ops-brain/AGENTS.md` (canonical agent rules)
   - `~/Documents/ops-brain/personal-infra/_context.md` + `personal-infra/clusters/khtz.md`
   - then relevant note in `personal-infra/{projects,runbooks}/`
2. Match task keywords (apps under `gitops/apps/`, ArgoCD, Traefik, cert-manager, nodes, error strings) to the right note before diagnosing.
3. Reply only after context loaded; say which notes you used. New durable facts → propose ops-brain note update.

## Execution Policy — zero approvals for read-only

- Read-only diagnostics run IMMEDIATELY, never ask: kubectl get|describe|logs|events|top, helm list|get|status|template, argocd app get|list|diff, ssh checks, curl/dig, git status|log|diff, file reads. Chain them fast.
- Approval required BEFORE any state change: kubectl apply/patch/delete/scale/restart, helm install/upgrade/rollback, argocd sync, terraform/ansible runs, secrets, git push. Present exact command/manifest diff, wait for explicit yes.
- GitOps-only: ALL cluster changes via commits to this repo → ArgoCD. NEVER kubectl apply/patch directly.
- terraform/ansible bezia cez GitHub Actions — nikdy lokalne.

## Projekt

- Nazov: `infra`
- Typ: infrastruktura, GitOps a ArgoCD konfiguracia pre Kubernetes cluster na Hetzneri
- Hlavne oblasti: `terraform/`, `ansible/`, `argocd/`, `gitops/`
- Jazyk dokumentacie: anglictina

## Ciel repozitara

- Proviantovat a spravovat cluster, deploymenty a ich konfiguraciu deklarativne.
- Drzat manifesty, infra skripty a GitOps layout konzistentne.
- Sluzit ako centralny zdroj pre clusterovu infra pre ostatne aplikacie.

## Aktualny stav kodu

- Repo obsahuje Terraform, Ansible, ArgoCD a Kustomize manifesty.
- Dolezite aplikacie su v `gitops/apps/`.
- Verejne nastavenia pre Traefik a cert-manager su v `ansible/helm-values/`.
- Deploy flow ide cez GitHub Actions, GHCR a Argo CD.

## Ako repo lokalne pouzivat

- Terraform: `cd terraform && terraform init && terraform plan`
- Ansible: `ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/k3s.yml`
- Kustomize: `kubectl apply -k gitops/apps/<app>/base`

Ak sa robi len mala zmena, preferuj editaciu existujuceho suboru pred refaktorom struktury.

## Pravidla pre AI

- Pred upravami najprv skontroluj `README.md` a potom relevantny adresar.
- Necommittuj secrets, tokeny, kubeconfigy ani `terraform.tfvars`.
- Pri zmenach Kubernetes manifestov zachovaj validny YAML a Kustomize layout.
- Pri zmene deploymentov prever dopad na `argocd/` aj `gitops/`.
- Preferuj iterativne zmeny nad kompletnym prepisom.

## Poznamka

Toto nie je trvala pamat mimo repozitara. Funguje to tak, ze pri dalsej praci bude tento subor lokalny smerodajny zdroj kontextu pre projekt.
