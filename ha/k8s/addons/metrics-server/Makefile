.PHONY: install upgrade uninstall

install:
	helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
	helm repo update
	helm dependency update
	helm install metrics-server . -n kube-system --create-namespace

upgrade:
	helm repo update
	helm dependency update
	helm upgrade metrics-server . -n kube-system

uninstall:
	helm uninstall metrics-server -n kube-system

template:
	helm dependency update
	helm template metrics-server . -n kube-system
