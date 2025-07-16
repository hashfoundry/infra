.PHONY: install uninstall upgrade upgrade-safe status

NAMESPACE = monitoring
RELEASE_NAME = grafana

install:
	helm dependency update
	helm upgrade --install $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--values values.yaml \
		--wait

uninstall:
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

upgrade:
	helm dependency update
	helm upgrade $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--values values.yaml \
		--wait

status:
	helm status $(RELEASE_NAME) --namespace $(NAMESPACE)
	kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=grafana

logs:
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=grafana --tail=100 -f

password:
	@echo "Grafana admin password:"
	@kubectl get secret --namespace $(NAMESPACE) grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

upgrade-safe:
	@echo "🔄 Performing safe Grafana upgrade with Recreate strategy..."
	@chmod +x upgrade.sh
	@./upgrade.sh

strategy:
	@echo "📊 Current deployment strategy:"
	@kubectl get deployment $(RELEASE_NAME) -n $(NAMESPACE) -o jsonpath='{.spec.strategy.type}' 2>/dev/null || echo "Deployment not found"
