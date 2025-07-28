- установить servicemonitor
- kubectl get componentstatuses - не актуален, заменить описание
- указать что для managed k8s нет доступа до control plane
- важное правило которые нужно держать в голове - это то что для работы hpa нужен metrics server
-
# Проверить сетевую связность между Pod'ами
kubectl exec -it <pod1> -n argocd -- ping <pod2-ip>
- # Скопировать файл в/из Pod'а
kubectl cp test-pod:/etc/nginx/nginx.conf ./nginx.conf
- Multi-Container Pod (sidecar pattern):
- Init Container Pattern:
- есть HPA а есть VPA (VPA - это какая-то дичь)
- можно ли запредить dns/доступ из одного неймспейса подам из другого неймспейса?