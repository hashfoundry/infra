- установить servicemonitor
- kubectl get componentstatuses - не актуален, заменить описание
- указать что для managed k8s нет доступа до control plane
- важное правило которые нужно держать в голове - это то что для работы hpa нужен metrics server
-
- Проверить сетевую связность между Pod'ами `kubectl exec -it <pod1> -n argocd -- ping <pod2-ip>`
- Скопировать файл в/из Pod'а `kubectl cp test-pod:/etc/nginx/nginx.conf ./nginx.conf`
- Multi-Container Pod (sidecar pattern):
- Init Container Pattern:
- есть HPA а есть VPA (VPA - это какая-то дичь)
- можно ли запредить dns/доступ из одного неймспейса подам из другого неймспейса?

- при определении resource request/limits - может ли что-то обно быть определено
- etcd - как получить доступ? можно ли обращаться напрямую? как посмотреть логи? как делать бэкапы? как делать хэлс-чеки? ключевые метрики?
- kubeapi - как получить доступ? можно ли обращаться напрямую? как посмотреть логи?
- принцип работы clusterIP, NodePort, LoadBalancer, ExternalName
- session affinity и прочие affinity
- `kubectl get lease kube-controller-manager -n kube-system -o yaml`
- `kubectl explain deployment`
- `kubectl get resourcequotas -A`, QoS Classes, мониторинг CPU throttling, мониторинг OOMKilled события, vertical pod autoscaler
- `kubectl logs <pod-name> --previous` - посмотреть логи с предыдущего запуска, статусы в которых может находиться под, kubectl debug <pod-name> -it --image=busybox --target=<container-name>

- scheduler:
```bash
# Pod'ы с resource requests
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 5 "Requests:"
# Scheduler не разместит Pod, если недостаточно ресурсов
kubectl describe pod <pod-name> -n argocd | grep -A 10 "Events:"
# пример
alexanderrodnin@MacBook-Air-3 infra % k describe pod argocd-server-84cdbdfb6-c26z6 -n argocd | grep -A 25 "Events"
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  17m   default-scheduler  Successfully assigned argocd/argocd-server-84cdbdfb6-c26z6 to ha-worker-pool-2nsdm
  Normal  Pulling    17m   kubelet            Pulling image "quay.io/argoproj/argocd:v2.10.1"
  Normal  Pulled     17m   kubelet            Successfully pulled image "quay.io/argoproj/argocd:v2.10.1" in 13.662s (13.662s including waiting). Image size: 169935379 bytes.
  Normal  Created    17m   kubelet            Created container: server
  Normal  Started    17m   kubelet            Started container server
  
  
## Affinity!
# ArgoCD использует anti-affinity для распределения по Node'ам
kubectl describe pod <argocd-server-pod> -n argocd | grep -A 10 "Affinity:"

# Scheduler размещает Pod'ы на разных Node'ах
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o wide

# Демонстрация планирования:

# Простой Pod - Scheduler выберет любую подходящую Node
kubectl run simple-pod --image=nginx
# Посмотреть на какой Node попал
kubectl get pod simple-pod -o wide
# События планирования
kubectl describe pod simple-pod | grep -A 5 "Events:"
# Очистка
kubectl delete pod simple-pod
```

```bash
# Pod с anti-affinity (не размещать рядом с другими nginx Pod'ами)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: anti-affinity-pod
  labels:
    app: nginx
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - nginx
        topologyKey: kubernetes.io/hostname
  containers:
  - name: nginx
    image: nginx
EOF

# Scheduler разместит на Node без других nginx Pod'ов
kubectl get pods -l app=nginx -o wide

# Очистка
kubectl delete pod anti-affinity-pod
```

```bash
# События успешного планирования
kubectl get events --field-selector reason=Scheduled

# События неудачного планирования
kubectl get events --field-selector reason=FailedScheduling

# Подробности о проблемах планирования
kubectl describe pod <pending-pod> | grep -A 10 "Events:"
```
выяснить какое поведение будет если указать больше ресурсов чем есть и не позволяет масштабирование,
как работает VPA,

## Kubelet
Компонент worker node.
Связующее звено между control plane и worker node.

- управляет подами
- взаимодействует с CRI


## Kube-proxy
- сетевой компонент (настаивает сетевое взаимодействие)
- ставится на workder-node, может быть и на control-plane если у неё стоит taint
- реализует типы балансировки:
```bash
ClusterIP,
NodePort, 
LoadBalancer,
External Name (выяснить как это работает)
```
- режимы работы:
```bash
IpTables (по-умолчанию) 
IPVS
```
- Обрабатывает **session affinity**


## Сбор логов по компонентам:
```bash
# Логи kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy

# Фильтровать по конкретной Node
kubectl logs -n kube-system -l k8s-app=kube-proxy --field-selector spec.nodeName=<node-name>
```

## Controller Manager
**kube-controller-manager** — это компонент Control plane который запускает различные типы контроллеров для поддержания состояния актуальности кластера. КРАТКО: поддерживает желаемое состояние кластера.

Основные типы контроллеров 
- Deployment Controller
- StatefulSet Controller
- Node Controller

```
┌────────────────────────────────────────────────────────────┐
│                    Controller Loop                         │
├────────────────────────────────────────────────────────────┤
│  1. Watch API Server                                       │
│     ├── Monitor resource changes                           │
│     ├── Get current state                                  │
│     └── Compare with desired state                         │
├────────────────────────────────────────────────────────────┤
│  2. Reconcile                                              │
│     ├── Calculate diff                                     │
│     ├── Plan actions                                       │
│     └── Execute changes                                    │
├────────────────────────────────────────────────────────────┤
│  3. Update Status                                          │
│     ├── Report back to API Server                          │
│     ├── Update resource status                             │
│     └── Generate events                                    │
├────────────────────────────────────────────────────────────┤
│  4. Repeat                                                 │
│     └── Continue monitoring                                │
└────────────────────────────────────────────────────────────┘
```

## 17. Разница между kube-controller-manager и cloud-controller-manager
### **kube-controller-manager:**
```
┌─────────────────────────────────────────────────────────────┐
│              kube-controller-manager                        │
├─────────────────────────────────────────────────────────────┤
│  Core Controllers:                                          │
│  ├── Deployment Controller                                  │
│  ├── ReplicaSet Controller                                  │
│  ├── DaemonSet Controller                                   │
│  ├── Job Controller                                         │
│  ├── CronJob Controller                                     │
│  ├── StatefulSet Controller                                 │
│  ├── Namespace Controller                                   │
│  ├── ServiceAccount Controller                              │
│  ├── Endpoint Controller                                    │
│  ├── ResourceQuota Controller                               │
│  ├── PersistentVolume Controller                            │
│  └── Certificate Controller                                 │
└─────────────────────────────────────────────────────────────┘
```

### **cloud-controller-manager:**
```
┌─────────────────────────────────────────────────────────────┐
│            cloud-controller-manager                         │
├─────────────────────────────────────────────────────────────┤
│  Cloud-Specific Controllers:                                │
│  ├── Node Controller                                        │
│  │   ├── Node lifecycle management                         │
│  │   ├── Node labeling (zones, instance types)             │
│  │   └── Node deletion handling                            │
│  ├── Route Controller                                       │
│  │   ├── Pod network routes                                │
│  │   └── Cross-node communication                          │
│  ├── Service Controller                                     │
│  │   ├── LoadBalancer provisioning                         │
│  │   ├── External IP assignment                            │
│  │   └── Cloud LB integration                              │
│  └── Volume Controller                                      │
│      ├── PV provisioning                                   │
│      ├── Volume attachment/detachment                      │
│      └── Storage class integration                         │
└─────────────────────────────────────────────────────────────┘
```

## **Lead Election**
Процесс определения лидера

### **Control Plane компоненты:**
```bash
# kube-controller-manager в HA режиме
kubectl describe lease kube-controller-manager -n kube-system

# kube-scheduler в HA режиме  
kubectl describe lease kube-scheduler -n kube-system

# Только один экземпляр каждого компонента активен
```

### **Настройка времени:**
- leaseDurationSeconds: 15-30 секунд
- renewDeadline: 10-20 секунд
- retryPeriod: 2-5 секунд
- Баланс между быстрым failover и стабильностью



## **Container runtime interfase (CRI)**
стандартный API между kubelet и container runtime.   
Запускает POD-ы  

```
┌────────────────────────────────────────────────────────────┐
│                        kubelet                             │
├────────────────────────────────────────────────────────────┤
│  CRI Client                                                │
│  ├── RuntimeService Client                                 │
│  │   ├── RunPodSandbox()                                   │
│  │   ├── StopPodSandbox()                                  │
│  │   ├── CreateContainer()                                 │
│  │   ├── StartContainer()                                  │
│  │   ├── StopContainer()                                   │
│  │   └── RemoveContainer()                                 │
│  └── ImageService Client                                   │
│      ├── PullImage()                                       │
│      ├── RemoveImage()                                     │
│      ├── ImageStatus()                                     │
│      └── ListImages()                                      │
└────────────────────────────────────────────────────────────┘
```

# **Версионирование в K8s**
## **Выбор API версий:**
- Используйте stable (v1) для production
- Избегайте alpha в production
- Тестируйте beta версии
- Следите за deprecation notices

# Управлеине Pod-ami

### Init-containers
- Запускаются последовательно в случае удачного завершения предыдущего
- При рестарте выполняются заново
- Должны быть идемпотентны
- поддерживают retry логику
- у них общие volume, остальное - разное

### Примеры использования
- подготовка окружения: (распаковка архивов, загрузка конфигураций в volume)
- безопасность (скачивание ключей, секьюрити чеки)
- базы (инициализация базы)
- ожидание внешних сервисов
- проверка валидности конфигураций

# Multicontainer pods
Поды содержащие несколько контейнеров, которые работают вместе как единое целое. Разделяют сеть, envs, storage и жизненный цикл.

Классческие паттерны использования:
- sidecar (расширяет или улучшает функционал основного контейнера. пример: Istio Envoy Proxy — автоматически вставляется в Pod, чтобы перехватывать и шифровать трафик (mTLS))
- ambassador (адаптирует интерфейс для внешних запросов. то есть когда кто-то снаружи предоставляет интерфейс в определенном формате и мы можем модифицировать только наш компонент)
- adapter (адаптирует интерфейс приложения для внешних потребителей. то есть когда кто-то снаружи запрашивает в определенном формате)

# **Resource Requests и Limits**
Механизмы управления ресурсами в K8s. Requests - минимальное значения ресурсов, Limits - максимальное значение ресурсов.  

При превышении лимитов по:
- памяти срабатывае OOMKiller (Out of Memory Killer)
- при привышении по CPU - возникает throatling


# **Инструменты отладки неработающего Pod**
```bash
# Шаг 1 - Проверка статуса:
kubectl describe pod

# Шаг 2 - Анализ событий:
# События конкретного Pod'а
kubectl get events --field-selector involvedObject.name=<pod-name>
# Все события в namespace
kubectl get events -n <namespace> --sort-by=.metadata.creationTimestamp
# События последних 1 часа
kubectl get events --field-selector involvedObject.name=<pod-name> --sort-by=.metadata.creationTimestamp | grep "$(date -d '1 hour ago' '+%Y-%m-%d')"

# Шаг 3 - Изучение логов
# Текущие логи
kubectl logs <pod-name>
# Логи конкретного контейнера
kubectl logs <pod-name> -c <container-name>
# Предыдущие логи (при рестарте)
kubectl logs <pod-name> --previous
# Следить за логами в реальном времени
kubectl logs <pod-name> -f
# Логи всех контейнеров
kubectl logs <pod-name> --all-containers=true

# Шаг 4 - Интерактивная отладка
# Выполнить команду в Pod'е
kubectl exec <pod-name> -- <command>
# Интерактивная сессия
kubectl exec -it <pod-name> -- /bin/bash
# Для конкретного контейнера
kubectl exec -it <pod-name> -c <container-name> -- /bin/sh
# Копирование файлов
kubectl cp <pod-name>:/path/to/file ./local-file
kubectl cp ./local-file <pod-name>:/path/to/file
```

```bash
# посмотреть логи предыдущего упавшего пода:
kubectl logs <pod-name> -p
```

Типичные проблемы:
- ImagePullBackOff / ErrImagePull
- CrashLoopBackOff
- Pending Pod'ы (ресурсов не хватает)
- OOMKilled Pod'ы

### **Debug контейнеры (Kubernetes 1.23+):**
```bash
# Добавить debug контейнер к существующему Pod'у
kubectl debug <pod-name> -it --image=busybox --target=<container-name>
# Создать копию Pod'а для отладки
kubectl debug <pod-name> -it --copy-to=debug-pod --container=debug --image=busybox
```


## **Pos security context**  
[Pos security context ](./03-Управление%20Pod-ами/025-что-такое-pod-security-contexts.md)

**k8s security context** - набор настроек безопасности, применяемых к POD-у или контейнеру.  Определяет права доступа, пользователей, группы, capabilities и другие параметры безопсности для выполнения контейнеров.

### Основные компоненты Security Context

#### User и Group ID
- runAsUser - UID пользователя
- runAsGroup - GID группы
- runAsNonRoot - запрет запуска от root
- fsGroup - группа для файловой системы

#### Capabilities
- add - добавить Linux capablities
- drop - убрать Linux capabilities
- Контроль системных привелегий

#### SELinux/AppArmor
- seLinuxOptions - настройка SELinux
- appArmorProfile - профиль AppArmor
- seccompProfile - профиль seccomp

#### Priveleged режим (НЕЛЬЗЯ использовать в проде)
- priveleged - привелегированный контейнер
- allowPrivilegeEscalation - резрешение повышения привилегий 
- readOnlyRootFilesystem - только для чтения корневой ФС

### Проверка security context
```bash
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{.spec.securityContext}{"\n"}{range .spec.containers[*]}{.name}: {.securityContext}{"\n"}{end}{"\n"}{end}'
```


## **Container restarts**
Механизм K8s автоматического перезапуска container-ов в случае сбоя или при завершении
- always (по-умолчанию) (всегда, подходит для deployment, statefull set)
- on failure (подходит для Job, Batch Job) (стабатывает в случае exit code != 0)
- never подходит для одноразовых задач

## **Quality of service - QoS**
**QoS** - система квалификации POD-ов в k8s на основе их resource requests и resource limits. Определеяет приоретет подов при нехватке ресурсов и влияет на решение какие из подов будут evicted первыми.

Вот приоритет в порядке убывания:
- **Guarantee** (requests == limits)
- **Burstable** (requests < limits)
- **BestEffort** (requests и limits не определены)

```bash
# получение QoS
kubectl get pods -A -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```

## **Liveness и Readiness probes**

**Health probes** - механизм k8s проверки состояния контейнеров

- **Liveness Probe** (Проверяет, что контейнер работает, При неудаче контейнер перезапускается, Предотвращает "зависшие" контейнеры)
- **Readiness Probe** (Проверяет готовность принимать трафик, При неудаче Pod исключается из Service, Не влияет на перезапуск контейнера)
- **Startup Probe (Kubernetes 1.16+)** (Проверяет успешный запуск контейнера, Отключает liveness/readiness до успешного старта, Полезно для медленно стартующих приложений)

**TODO**: это же можно настроить и как на уровне приложения так и на уровне k8s (или я чего-то не понимаю)  

| Параметр                           | Описание |
|------------------------------------|----------|
| **initialDelaySeconds**            | Время (в секундах) ожидания перед первой проверкой после старта контейнера. |
| **periodSeconds**                  | Интервал (в секундах) между проверками. |
| **timeoutSeconds**                 | Время ожидания ответа от проверки, после которого она считается неуспешной. |
| **successThreshold**                | Кол-во подряд успешных проверок для признания контейнера “здоровым” (для readiness и startup). |
| **failureThreshold**                | Кол-во подряд неудачных проверок для признания контейнера “нездоровым”. |
| **httpGet**                         | HTTP-запрос для проверки (`path`, `port`, `host`, `scheme`, `httpHeaders`). |
| **tcpSocket**                       | TCP-проверка доступности порта (`port`, `host`). |
| **exec**                            | Запуск команды внутри контейнера для проверки здоровья (`command`). |
| **terminationGracePeriodSeconds**   | (Опционально) Сколько ждать после SIGTERM перед принудительным завершением, если probe определил, что контейнер нездоров. |

## **Pod Disruption Budget**

**PBB** - это ресурс K8s, который ограничивает полличество подов которые могутбыть одновременно недоступны во время voluntary disruptions (плановых (и только плановых!) нарушений). PDB обеспечивает HA приложений.  

**Voluntary Disruption** (Плановые):
- обновление Deployment-ов
- Drain Node-ов для обслуживания
- Масштабирование кластера
- Обновление Node-ов

### 🔹 Что происходит при drain
1. **Ставится taint** `node.kubernetes.io/unschedulable:NoSchedule`  
   → новые Pod’ы больше не планируются на эту ноду.
2. Kubernetes **корректно завершает Pod’ы**, перемещая их на другие ноды:
    - Учитывает `PodDisruptionBudget` (PDB)
    - Уважает `terminationGracePeriodSeconds`
3. **Pod’ы с `replicaSet` или `deployment`** пересоздаются на других нодах.
4. **Pod’ы без контроллеров** (standalone) удаляются и **не восстанавливаются**.

### 🔹 Команда для drain
```bash
kubectl drain <node-name>
```

### 📋 Основные параметры PodDisruptionBudget (PDB)

| Параметр             | Тип     | Описание |
|----------------------|---------|----------|
| **minAvailable**     | string / int | Минимальное количество Pod’ов, которое должно оставаться доступным во время добровольных остановок (можно указать число или процент). |
| **maxUnavailable**   | string / int | Максимальное количество Pod’ов, которое может быть недоступно во время добровольных остановок (можно указать число или процент). |
| **selector**         | object  | Метка (`label selector`), определяющая, к каким Pod’ам применяется PDB. |
| **unhealthyPodEvictionPolicy** | string | Политика удаления Pod’ов, находящихся в состоянии `NotReady` (`AlwaysAllow` или `IfHealthyBudget`). По умолчанию — `IfHealthyBudget`. |


## DNS для POD-ов

**DNS в K8s** - это система разрешения имен, которая позволяет Pod-ом находить друг друга и сервисы по именам вместо IP-адресов. Использует компонент coredns.

### Пример:
```bash
# DNS записи для Service:
# web-service.default.svc.cluster.local (полное имя)
# web-service.default.svc (без домена кластера)
# web-service.default (без svc)
# web-service (в том же namespace)
```

