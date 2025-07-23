# HashFoundry Blockchain Helm Chart Management

.PHONY: help template install upgrade uninstall lint test clean

NAMESPACE ?= blockchain
RELEASE_NAME ?= hashfoundry-blockchain
CHART_PATH ?= .

help: ## Show this help message
	@echo "HashFoundry Blockchain Helm Chart Management"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

template: ## Generate Kubernetes manifests from templates
	@echo "🔍 Generating Kubernetes manifests from Helm templates..."
	helm template $(RELEASE_NAME) $(CHART_PATH) --namespace $(NAMESPACE)

install: ## Install the blockchain Helm chart
	@echo "🚀 Installing HashFoundry Blockchain..."
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm install $(RELEASE_NAME) $(CHART_PATH) --namespace $(NAMESPACE) --create-namespace

upgrade: ## Upgrade the blockchain Helm chart
	@echo "⬆️  Upgrading HashFoundry Blockchain..."
	helm upgrade $(RELEASE_NAME) $(CHART_PATH) --namespace $(NAMESPACE)

uninstall: ## Uninstall the blockchain Helm chart
	@echo "🗑️  Uninstalling HashFoundry Blockchain..."
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

lint: ## Lint the Helm chart
	@echo "🔍 Linting Helm chart..."
	helm lint $(CHART_PATH)

test: ## Test the Helm chart (dry-run install)
	@echo "🧪 Testing Helm chart (dry-run)..."
	helm install $(RELEASE_NAME) $(CHART_PATH) --namespace $(NAMESPACE) --dry-run --debug

validate: ## Validate the Helm chart templates
	@echo "✅ Validating Helm chart templates..."
	helm template $(RELEASE_NAME) $(CHART_PATH) --namespace $(NAMESPACE) --validate

clean: ## Remove generated files
	@echo "🧹 Cleaning up generated files..."
	rm -f *.yaml.bak
	rm -f *.tmp

status: ## Show blockchain deployment status
	@echo "📊 Blockchain deployment status:"
	@echo ""
	@echo "🏷️  Helm release:"
	helm status $(RELEASE_NAME) --namespace $(NAMESPACE) || echo "Release not found"
	@echo ""
	@echo "🔗 Services:"
	kubectl get services -n $(NAMESPACE) -l app.kubernetes.io/name=blockchain || echo "No services found"
	@echo ""
	@echo "📦 Pods:"
	kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=blockchain || echo "No pods found"
	@echo ""
	@echo "📈 Ingress:"
	kubectl get ingress -n $(NAMESPACE) || echo "No ingress found"

logs-alice: ## Show Alice validator logs
	@echo "📋 Alice validator logs:"
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=validator-alice --tail=50

logs-bob: ## Show Bob validator logs
	@echo "📋 Bob validator logs:"
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=validator-bob --tail=50

port-forward-alice: ## Port forward to Alice RPC endpoint
	@echo "🔗 Port forwarding to Alice RPC (localhost:9933)..."
	kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME)-alice 9933:9933

port-forward-bob: ## Port forward to Bob RPC endpoint
	@echo "🔗 Port forwarding to Bob RPC (localhost:9934)..."
	kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME)-bob 9934:9933

debug: ## Debug the blockchain deployment
	@echo "🐛 Debugging blockchain deployment..."
	@echo ""
	@echo "📦 Pod status:"
	kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=blockchain -o wide
	@echo ""
	@echo "📊 Pod describe (Alice):"
	kubectl describe pod -n $(NAMESPACE) -l app.kubernetes.io/component=validator-alice
	@echo ""
	@echo "📊 Pod describe (Bob):"
	kubectl describe pod -n $(NAMESPACE) -l app.kubernetes.io/component=validator-bob
	@echo ""
	@echo "🔍 Events:"
	kubectl get events -n $(NAMESPACE) --sort-by=.metadata.creationTimestamp

# Development targets
dev-install: lint test install ## Development workflow: lint, test, then install
dev-upgrade: lint test upgrade ## Development workflow: lint, test, then upgrade

# Production targets
prod-install: validate install ## Production workflow: validate, then install
prod-upgrade: validate upgrade ## Production workflow: validate, then upgrade
