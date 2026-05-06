# Uptime Kuma — Manual Setup

Deployed via Ansible as Docker on the Hetzner node (outside k3s).  
Dashboard: **https://status.filipcsupka.online**

---

## First-time setup

### 1. Open the dashboard

Go to https://status.filipcsupka.online  
Create your admin account (username + password of your choice).

---

### 2. Add monitors

Add → New Monitor for each entry below.

**Type: HTTP(s)** for all public sites and ArgoCD/Traefik.  
**Type: HTTP(s) — keyword** for k3s API (keyword: `ok`, ignore TLS cert).

| Name | URL | Notes |
|------|-----|-------|
| vevsdesign.sk | https://vevsdesign.sk | |
| www.vevsdesign.sk | https://www.vevsdesign.sk | |
| filipcsupka.online | https://filipcsupka.online | |
| www.filipcsupka.online | https://www.filipcsupka.online | |
| k3s API | https://host.docker.internal:6443/healthz | keyword: `ok`, ignore TLS |
| ArgoCD | http://host.docker.internal:30080 | |
| Traefik | http://host.docker.internal:80 | |

Interval: 60s, Max retries: 3 (recommended for all).

---

## Maintenance

**Update Kuma** (pulls latest 2.x image):
```bash
cd /opt/monitoring
docker compose pull
docker compose up -d
```

**View logs:**
```bash
docker logs uptime-kuma -f
```

**Data location:** Docker volume `uptime-kuma-data` (persists across restarts and image updates).

---

## Re-deploy from scratch

Push any change to `monitoring/**` or `ansible/playbooks/monitoring.yml` → GH Actions re-runs.  
Or trigger manually: Actions → Monitoring → Run workflow.
