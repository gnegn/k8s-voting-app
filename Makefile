.PHONY: help \
	up clean \
	docker-build docker-load docker-up docker-down docker-logs \
	kind-create kind-delete kind-status \
	argocd-install argocd-apply-local argocd-apply-eks \
	argocd-password argocd-port-forward \
	monitoring-grafana monitoring-prometheus grafana-password \
	eks-create eks-destroy eks-kubeconfig eks-argocd-install \
	port-forward-vote port-forward-result

.DEFAULT_GOAL := help

# ── Variables ─────────────────────────────────────────────────
REGISTRY     ?= ghcr.io/YOUR_USERNAME
TAG          ?= latest
CLUSTER_NAME ?= voting-cluster
NAMESPACE    ?= voting

# ─────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  K8s Voting App — Portfolio Project"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ \
		{ printf "  \033[36m%-35s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

# ── Full local setup ──────────────────────────────────────────
up: ## Build → cluster → load → argocd → wait → status
	$(MAKE) docker-build
	$(MAKE) kind-create
	$(MAKE) docker-load
	$(MAKE) argocd-install
	$(MAKE) argocd-apply-local
	@echo "\n Waiting for pods to be ready..."
	kubectl wait --for=condition=ready pod --all -n $(NAMESPACE) --timeout=180s
	kubectl get pods -n $(NAMESPACE) -o wide

# ── Docker ────────────────────────────────────────────────────
docker-build: ## Build all images locally
	docker build -t voting-vote:local   ./app/vote
	docker build -t voting-result:local ./app/result
	docker build -t voting-worker:local ./app/worker

docker-load: ## Load images into kind cluster
	kind load docker-image voting-vote:local   --name $(CLUSTER_NAME)
	kind load docker-image voting-result:local --name $(CLUSTER_NAME)
	kind load docker-image voting-worker:local --name $(CLUSTER_NAME)

docker-up: ## Start app locally via docker-compose
	docker compose -f docker/docker-compose.yml up --build

docker-down: ## Stop docker-compose
	docker compose -f docker/docker-compose.yml down -v

docker-logs: ## Follow docker-compose logs
	docker compose -f docker/docker-compose.yml logs -f

# ── kind ──────────────────────────────────────────────────────
kind-create: ## Create local kind cluster
	kind create cluster --name $(CLUSTER_NAME) --config docker/kind-config.yaml
	kubectl cluster-info --context kind-$(CLUSTER_NAME)

kind-delete: ## Delete kind cluster
	kind delete cluster --name $(CLUSTER_NAME)

kind-status: ## Show cluster nodes
	kubectl get nodes -o wide

# ── Argo CD ───────────────────────────────────────────────────
argocd-install: ## Install Argo CD via Helm
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	helm upgrade --install argocd argo/argo-cd \
		--namespace argocd --create-namespace \
		--values argocd/install/argocd-values.yaml \
		--wait

argocd-apply-local: ## Apply app-of-apps for kind (values-local.yaml)
	kubectl apply -f argocd/app-of-apps.yaml
	kubectl apply -f argocd/apps/voting-app.yaml

argocd-apply-eks: ## Apply app-of-apps for EKS (values-eks.yaml)
	kubectl apply -f argocd/app-of-apps.yaml
	kubectl apply -f argocd/apps/voting-app-eks.yaml

argocd-password: ## Get Argo CD admin password
	kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d && echo

argocd-port-forward: ## Open Argo CD UI → localhost:8080
	kubectl port-forward svc/argocd-server -n argocd 8080:443

# ── Monitoring ────────────────────────────────────────────────
monitoring-grafana: ## Open Grafana → localhost:3000
	kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80

monitoring-prometheus: ## Open Prometheus → localhost:9090
	kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090

grafana-password: ## Get Grafana admin password
	kubectl get secret -n monitoring monitoring-grafana \
		-o jsonpath="{.data.admin-password}" | base64 -d && echo

# ── AWS EKS ───────────────────────────────────────────────────
eks-create: ## Create EKS cluster via Terraform
	cd terraform && terraform init && terraform apply -auto-approve

eks-destroy: ## Destroy EKS cluster
	cd terraform && terraform destroy -auto-approve

eks-kubeconfig: ## Configure kubectl for EKS
	aws eks update-kubeconfig --name voting-eks --region eu-west-1

eks-argocd-install: ## Install Argo CD on EKS and apply EKS apps
	$(MAKE) argocd-install
	$(MAKE) argocd-apply-eks

# ── Utils ─────────────────────────────────────────────────────
port-forward-vote: ## Port-forward vote → localhost:5000
	kubectl port-forward svc/vote -n $(NAMESPACE) 5000:5000

port-forward-result: ## Port-forward result → localhost:5001
	kubectl port-forward svc/result -n $(NAMESPACE) 5001:5001

clean: ## Delete kind cluster and docker artifacts
	kind delete cluster --name $(CLUSTER_NAME) || true
	docker compose -f docker/docker-compose.yml down -v --remove-orphans || true	