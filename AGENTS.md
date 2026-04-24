# AGENTS.md

Tento subor je kanonicky kontext pre AI asistenta pracujuceho na repo `infra`.
Ak je nieco v konflikte medzi tymto suborom a starsim obsahom inde v projekte, preferuj tento subor.

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
