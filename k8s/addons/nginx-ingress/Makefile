deploy-dev:
	helm dep up
	kubectl config use-context hashfoundry-dev
	helm upgrade --install --create-namespace -n ingress-nginx nginx-ingress . -f values.yaml

deploy-staging:
	helm dep up
	kubectl config use-context hashfoundry-staging
	helm upgrade --install --create-namespace -n ingress-nginx nginx-ingress . -f values.yaml

deploy-prod:
	helm dep up
	kubectl config use-context hashfoundry-prod
	helm upgrade --install --create-namespace -n ingress-nginx nginx-ingress . -f values.yaml

uninstall:
	helm uninstall nginx-ingress -n ingress-nginx
