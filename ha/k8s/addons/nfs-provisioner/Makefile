.PHONY: install uninstall upgrade lint test clean

CHART_NAME := nfs-provisioner
NAMESPACE := nfs-system
RELEASE_NAME := nfs-provisioner

install:
	@echo "Installing NFS Provisioner..."
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 10m

uninstall:
	@echo "Uninstalling NFS Provisioner..."
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true

upgrade:
	@echo "Upgrading NFS Provisioner..."
	helm upgrade $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--wait \
		--timeout 10m

lint:
	@echo "Linting Helm chart..."
	helm lint .

test:
	@echo "Testing NFS Provisioner..."
	kubectl apply -f test/test-pvc.yaml
	kubectl wait --for=condition=Bound pvc/test-nfs-pvc --timeout=60s
	kubectl delete -f test/test-pvc.yaml

clean:
	@echo "Cleaning up test resources..."
	kubectl delete pvc --all -n $(NAMESPACE) --ignore-not-found=true

status:
	@echo "NFS Provisioner status:"
	helm status $(RELEASE_NAME) --namespace $(NAMESPACE)
	kubectl get pods -n $(NAMESPACE)
	kubectl get pvc -n $(NAMESPACE)
	kubectl get storageclass $(CHART_NAME)

logs:
	@echo "NFS Server logs:"
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=nfs-server
	@echo "NFS Provisioner logs:"
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=nfs-provisioner
