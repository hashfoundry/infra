.PHONY: help install upgrade uninstall template lint

CHART_NAME := argocd-ingress
NAMESPACE := argocd
RELEASE_NAME := argocd-ingress

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install ArgoCD Ingress chart
	helm install $(RELEASE_NAME) . -n $(NAMESPACE) --create-namespace

upgrade: ## Upgrade ArgoCD Ingress chart
	helm upgrade $(RELEASE_NAME) . -n $(NAMESPACE)

uninstall: ## Uninstall ArgoCD Ingress chart
	helm uninstall $(RELEASE_NAME) -n $(NAMESPACE)

template: ## Generate templates without installing
	helm template $(RELEASE_NAME) . -n $(NAMESPACE)

lint: ## Lint the chart
	helm lint .

status: ## Show release status
	helm status $(RELEASE_NAME) -n $(NAMESPACE)

list: ## List releases
	helm list -n $(NAMESPACE)
