.PHONY: install uninstall upgrade status

NAMESPACE = monitoring
RELEASE_NAME = prometheus

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
	kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=prometheus

logs:
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=prometheus --tail=100 -f
