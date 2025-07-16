# NFS Exporter Makefile

CHART_NAME = nfs-exporter
NAMESPACE = monitoring
RELEASE_NAME = nfs-exporter

.PHONY: help install upgrade uninstall status template lint test

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install NFS Exporter
	@echo "Installing NFS Exporter..."
	helm upgrade --install $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--values values.yaml \
		--wait \
		--timeout 10m

upgrade: ## Upgrade NFS Exporter
	@echo "Upgrading NFS Exporter..."
	helm upgrade $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--values values.yaml \
		--wait \
		--timeout 10m

uninstall: ## Uninstall NFS Exporter
	@echo "Uninstalling NFS Exporter..."
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

status: ## Show NFS Exporter status
	@echo "=== Helm Release Status ==="
	helm status $(RELEASE_NAME) --namespace $(NAMESPACE)
	@echo ""
	@echo "=== Pods Status ==="
	kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=$(CHART_NAME)
	@echo ""
	@echo "=== Service Status ==="
	kubectl get svc -n $(NAMESPACE) -l app.kubernetes.io/name=$(CHART_NAME)
	@echo ""
	@echo "=== ServiceMonitor Status ==="
	kubectl get servicemonitor -n $(NAMESPACE) -l app.kubernetes.io/name=$(CHART_NAME)

template: ## Generate Kubernetes manifests
	@echo "Generating templates..."
	helm template $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--values values.yaml

lint: ## Lint Helm chart
	@echo "Linting Helm chart..."
	helm lint .

test: ## Test NFS Exporter metrics endpoint
	@echo "Testing NFS Exporter metrics endpoint..."
	@echo "Port-forwarding to NFS Exporter service..."
	kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME) 9100:9100 &
	@sleep 5
	@echo "Testing metrics endpoint..."
	curl -s http://localhost:9100/metrics | head -20
	@echo ""
	@echo "Stopping port-forward..."
	@pkill -f "kubectl port-forward.*$(RELEASE_NAME)"

logs: ## Show NFS Exporter logs
	@echo "Showing NFS Exporter logs..."
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=$(CHART_NAME) --tail=50 -f

describe: ## Describe NFS Exporter resources
	@echo "=== Deployment Description ==="
	kubectl describe deployment -n $(NAMESPACE) -l app.kubernetes.io/name=$(CHART_NAME)
	@echo ""
	@echo "=== Pod Description ==="
	kubectl describe pods -n $(NAMESPACE) -l app.kubernetes.io/name=$(CHART_NAME)

metrics: ## Show available metrics
	@echo "Available NFS metrics from node-exporter:"
	@echo "- node_nfs_requests_total: Total number of NFS requests"
	@echo "- node_nfs_connections_total: Total number of NFS connections"
	@echo "- node_nfsd_requests_total: Total number of NFS daemon requests"
	@echo "- node_nfsd_connections_total: Total number of NFS daemon connections"
	@echo "- node_filesystem_*: Filesystem metrics including NFS mounts"
	@echo ""
	@echo "To see actual metrics, run: make test"

clean: ## Clean up failed deployments
	@echo "Cleaning up failed deployments..."
	kubectl delete pods -n $(NAMESPACE) -l app.kubernetes.io/name=$(CHART_NAME) --field-selector=status.phase=Failed
