deploy-dev:
	helm dep up
	kubectl config use-context hashfoundry-dev
	helm upgrade --install --create-namespace -n argocd argo-cd-apps . -f values.yaml -f values.dev.yaml

deploy-staging:
	helm dep up
	kubectl config use-context hashfoundry-staging
	helm upgrade --install --create-namespace -n argocd argo-cd-apps . -f values.yaml -f values.staging.yaml

deploy-prod:
	helm dep up
	kubectl config use-context hashfoundry-prod
	helm upgrade --install --create-namespace -n argocd argo-cd-apps . -f values.yaml -f values.prod.yaml
