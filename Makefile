.PHONY: help \
	docker-up docker-down docker-logs docker-load docker-build\
	kind-create kind-delete kind-status kind-up \
	k8s-apply k8s-delete k8s-status \
	k8s-logs-vote k8s-logs-result k8s-logs-worker \
	helm-lint helm-install helm-uninstall \
	argocd-install argocd-password argocd-port-forward argocd-apply \
	monitoring-install monitoring-grafana monitoring-prometheus grafana-password \
	logging-install \
	eks-create eks-destroy eks-kubeconfig eks-deploy \
	port-forward-vote port-forward-result \
	clean

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

kind-up: ## Start build → cluster → load → deploy → status
	$(MAKE) docker-build
	$(MAKE) kind-create
	$(MAKE) docker-load
	$(MAKE) k8s-apply
	@echo "\nWaiting for pods to be ready..."
	kubectl wait --for=condition=ready pod --all -n $(NAMESPACE) --timeout=120s
	$(MAKE) k8s-status

# ── Docker ────────────────────────────────────────────
docker-up: ## Start the app locally using docker-compose
	docker compose -f docker/docker-compose.yml up --build

docker-down: ## Stop docker-compose
	docker compose -f docker/docker-compose.yml down -v

docker-logs: ## docker-compose logs
	docker compose -f docker/docker-compose.yml logs -f

docker-build: ## build docker images localy
	docker build -t voting-vote:local   ./app/vote
	docker build -t voting-result:local ./app/result
	docker build -t voting-worker:local ./app/worker

docker-load: ## load docker images to kind
	kind load docker-image voting-vote:local   --name voting-cluster
	kind load docker-image voting-result:local --name voting-cluster
	kind load docker-image voting-worker:local --name voting-cluster

# ── kind ──────────────────────────────────────────────
kind-create: ## Create a local kind cluster
	kind create cluster --name $(CLUSTER_NAME) --config docker/kind-config.yaml
	kubectl cluster-info --context kind-$(CLUSTER_NAME)

kind-delete: ## Delete kind cluster
	kind delete cluster --name $(CLUSTER_NAME)

kind-status: ## Show cluster nodes
	kubectl get nodes -o wide

# ──  k8s manifests ─────────────────────────────────────
k8s-apply: ## Apply k8s manifests
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/redis/
	kubectl apply -f k8s/postgres/
	kubectl apply -f k8s/worker/
	kubectl apply -f k8s/vote/
	kubectl apply -f k8s/result/

k8s-delete: ## Delete all k8s resources
	kubectl delete -f k8s/ --recursive --ignore-not-found

k8s-status: ## Show pods, services
	@echo "\n── Pods ─────────────────────────────────────────────"
	kubectl get pods -n $(NAMESPACE) -o wide
	@echo "\n── Services ─────────────────────────────────────────"
	kubectl get svc -n $(NAMESPACE)

k8s-logs-vote: ## Logs for vote service
	kubectl logs -n $(NAMESPACE) -l app=vote -f

k8s-logs-result: ## Logs for result service
	kubectl logs -n $(NAMESPACE) -l app=result -f

k8s-logs-worker: ## Logs for worker service
	kubectl logs -n $(NAMESPACE) -l app=worker -f

# ── Helm ──────────────────────────────────────────────
helm-lint: ## Lint helm chart
	helm lint ./helm/voting-app

helm-install: ## Deploy using Helm (kind)
	helm upgrade --install voting-app ./helm/voting-app \
		--namespace $(NAMESPACE) --create-namespace \
		--values helm/voting-app/values.yaml \
		--values helm/voting-app/values-local.yaml \
		--wait

helm-uninstall: ## Uninstall helm release
	helm uninstall voting-app -n $(NAMESPACE)

# ── Argo CD ───────────────────────────────────────────
argocd-install: ## Install Argo CD in the cluster
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl rollout status deploy/argocd-server -n argocd --timeout=120s

argocd-password: ## Get initial Argo CD password
	kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d && echo

argocd-port-forward: ## Open Argo CD UI → localhost:8080
	kubectl port-forward svc/argocd-server -n argocd 8080:443

argocd-apply: ## Apply Argo CD Application
	kubectl apply -f argocd/apps/application.yaml

# ── Monitoring ────────────────────────────────────────
monitoring-install: ## Install kube-prometheus-stack
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
		--namespace monitoring --create-namespace \
		--values monitoring/prometheus-values.yaml \
		--wait

monitoring-grafana: ## Open Grafana → localhost:3000
	kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80

monitoring-prometheus: ## Open Prometheus → localhost:9090
	kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090

grafana-password: ## Get Grafana password
	kubectl get secret -n monitoring monitoring-grafana \
		-o jsonpath="{.data.admin-password}" | base64 -d && echo

# ── Logging ───────────────────────────────────────────
logging-install: ## Install Loki stack
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update
	helm upgrade --install loki grafana/loki-stack \
		--namespace logging --create-namespace \
		--values logging/loki-values.yaml \
		--wait

# ── AWS EKS ───────────────────────────────────────────
eks-create: ## Create EKS cluster using Terraform
	cd terraform && terraform init && terraform apply -auto-approve

eks-destroy: ## Destroy EKS cluster
	cd terraform && terraform destroy -auto-approve

eks-kubeconfig: ## Get kubeconfig for EKS
	aws eks update-kubeconfig --name voting-eks --region eu-west-1

eks-deploy: ## Deploy to EKS using Helm
	helm upgrade --install voting-app ./helm/voting-app \
		--namespace $(NAMESPACE) --create-namespace \
		--values helm/voting-app/values.yaml \
		--values helm/voting-app/values-eks.yaml \
		--wait

# ── Utils ─────────────────────────────────────────────────────
port-forward-vote: ## Port-forward vote → localhost:5000
	kubectl port-forward svc/vote -n $(NAMESPACE) 5000:5000

port-forward-result: ## Port-forward result → localhost:5001
	kubectl port-forward svc/result -n $(NAMESPACE) 5001:5001

clean: ## Delete cluster and docker artifacts
	kind delete cluster --name $(CLUSTER_NAME) || true
	docker compose -f docker/docker-compose.yml down -v --remove-orphans || true