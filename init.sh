#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Creating k8s-voting-portfolio structure..."

# ── Root files ────────────────────────────────────────────────
touch Makefile
touch .env.example
touch .gitignore
touch README.md

# ── docker/ ───────────────────────────────────────────────────
mkdir -p docker
touch docker/docker-compose.yml
touch docker/kind-config.yaml

# ── k8s/ ──────────────────────────────────────────────────────
mkdir -p k8s/{vote,result,worker,redis,postgres}
touch k8s/namespace.yaml
touch k8s/vote/deployment.yaml
touch k8s/vote/service.yaml
touch k8s/result/deployment.yaml
touch k8s/result/service.yaml
touch k8s/worker/deployment.yaml
touch k8s/redis/deployment.yaml
touch k8s/redis/service.yaml
touch k8s/postgres/deployment.yaml
touch k8s/postgres/service.yaml
touch k8s/postgres/pvc.yaml

# ── helm/ ─────────────────────────────────────────────────────
mkdir -p helm/voting-app/templates/{vote,result,worker,redis,postgres}
touch helm/voting-app/Chart.yaml
touch helm/voting-app/values.yaml
touch helm/voting-app/values-local.yaml
touch helm/voting-app/values-eks.yaml
touch helm/voting-app/templates/_helpers.tpl
touch helm/voting-app/templates/vote/deployment.yaml
touch helm/voting-app/templates/vote/service.yaml
touch helm/voting-app/templates/result/deployment.yaml
touch helm/voting-app/templates/result/service.yaml
touch helm/voting-app/templates/worker/deployment.yaml
touch helm/voting-app/templates/redis/deployment.yaml
touch helm/voting-app/templates/redis/service.yaml
touch helm/voting-app/templates/postgres/deployment.yaml
touch helm/voting-app/templates/postgres/service.yaml
touch helm/voting-app/templates/postgres/pvc.yaml
touch helm/voting-app/templates/ingress.yaml

# ── argocd/ ───────────────────────────────────────────────────
mkdir -p argocd/{install,apps}
touch argocd/install/argocd-values.yaml
touch argocd/apps/application.yaml
touch argocd/apps/app-of-apps.yaml

# ── monitoring/ ───────────────────────────────────────────────
mkdir -p monitoring/dashboards
touch monitoring/prometheus-values.yaml
touch monitoring/dashboards/voting-app.json

# ── logging/ ──────────────────────────────────────────────────
mkdir -p logging
touch logging/loki-values.yaml

# ── terraform/ ────────────────────────────────────────────────
mkdir -p terraform/modules/{eks,vpc}
touch terraform/main.tf
touch terraform/variables.tf
touch terraform/outputs.tf
touch terraform/modules/eks/.gitkeep
touch terraform/modules/vpc/.gitkeep

echo ""
echo "✅ Done! Structure created:"
echo ""
find . -not -path './apps/*' -not -path './.git/*' | sort | \
  sed 's|[^/]*/|  |g; s|  \([^ ]\)|└─ \1|'