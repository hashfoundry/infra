# 98. Kubernetes Jobs и CronJobs

## 🎯 **Kubernetes Jobs и CronJobs**

**Jobs и CronJobs** - это ресурсы Kubernetes для выполнения задач, которые должны завершиться успешно. **Job** выполняет задачу один раз до успешного завершения, а **CronJob** запускает Jobs по расписанию, подобно cron в Unix-системах.

## 🏗️ **Компоненты Jobs и CronJobs:**

### **1. Job Types:**
- **One-time Job** - разовое выполнение задачи
- **Parallel Job** - параллельное выполнение
- **Work Queue Job** - обработка очереди задач
- **Indexed Job** - индексированные задачи

### **2. CronJob Features:**
- **Schedule** - расписание в формате cron
- **Job Template** - шаблон для создания Jobs
- **History Limits** - лимиты истории выполнения
- **Concurrency Policy** - политика параллельного выполнения

## 📊 **Практические примеры из вашего HA кластера:**

### **1. Анализ существующих Jobs и CronJobs:**
```bash
# Проверить существующие Jobs и CronJobs
kubectl get jobs --all-namespaces
kubectl get cronjobs --all-namespaces
```

### **2. Создание comprehensive Jobs и CronJobs toolkit:**
```bash
# Создать скрипт для работы с Jobs и CronJobs
cat << 'EOF' > kubernetes-jobs-cronjobs-toolkit.sh
#!/bin/bash

echo "=== Kubernetes Jobs and CronJobs Toolkit ==="
echo "Comprehensive toolkit for Jobs and CronJobs in HashFoundry HA cluster"
echo

# Функция для анализа текущих Jobs и CronJobs
analyze_current_jobs_cronjobs() {
    echo "=== Current Jobs and CronJobs Analysis ==="
    
    echo "1. Active Jobs:"
    echo "=============="
    kubectl get jobs --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,COMPLETIONS:.spec.completions,SUCCESSFUL:.status.succeeded,ACTIVE:.status.active,AGE:.metadata.creationTimestamp"
    echo
    
    echo "2. CronJobs:"
    echo "==========="
    kubectl get cronjobs --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,SCHEDULE:.spec.schedule,SUSPEND:.spec.suspend,ACTIVE:.status.active,LAST-SCHEDULE:.status.lastScheduleTime"
    echo
    
    echo "3. Failed Jobs:"
    echo "=============="
    kubectl get jobs --all-namespaces --field-selector status.successful!=1 -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,FAILED:.status.failed,CONDITIONS:.status.conditions[*].type"
    echo
    
    echo "4. Job Pods:"
    echo "==========="
    kubectl get pods --all-namespaces -l job-name -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,JOB:.metadata.labels.job-name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount"
    echo
}

# Функция для создания basic Job examples
create_basic_job_examples() {
    echo "=== Creating Basic Job Examples ==="
    
    # Создать namespace для примеров
    kubectl create namespace jobs-examples --dry-run=client -o yaml | kubectl apply -f -
    
    # Example 1: Simple one-time Job
    cat << SIMPLE_JOB_EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: simple-job
  namespace: jobs-examples
  labels:
    app.kubernetes.io/name: "simple-job"
    hashfoundry.io/example: "simple-job"
  annotations:
    hashfoundry.io/description: "Simple one-time job example"
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 3
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "simple-job"
        hashfoundry.io/job-type: "simple"
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.35
        command: ["/bin/sh"]
        args: ["-c", "echo 'Starting simple job'; sleep 30; echo 'Job completed successfully'; exit 0"]
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
        env:
        - name: JOB_TYPE
          value: "simple"
        - name: EXECUTION_TIME
          value: "30"
SIMPLE_JOB_EOF
    
    # Example 2: Parallel Job
    cat << PARALLEL_JOB_EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job
  namespace: jobs-examples
  labels:
    app.kubernetes.io/name: "parallel-job"
    hashfoundry.io/example: "parallel-job"
  annotations:
    hashfoundry.io/description: "Parallel job with multiple workers"
spec:
  completions: 6
  parallelism: 3
  backoffLimit: 2
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "parallel-job"
        hashfoundry.io/job-type: "parallel"
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.35
        command: ["/bin/sh"]
        args: ["-c", "echo 'Worker starting'; WORKER_ID=\$RANDOM; echo 'Worker ID: '\$WORKER_ID; sleep \$((10 + RANDOM % 20)); echo 'Worker '\$WORKER_ID' completed'"]
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
        env:
        - name: JOB_TYPE
          value: "parallel"
PARALLEL_JOB_EOF
    
    # Example 3: Work Queue Job
    cat << WORK_QUEUE_JOB_EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: work-queue-job
  namespace: jobs-examples
  labels:
    app.kubernetes.io/name: "work-queue-job"
    hashfoundry.io/example: "work-queue-job"
  annotations:
    hashfoundry.io/description: "Work queue job processing items"
spec:
  parallelism: 2
  backoffLimit: 4
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "work-queue-job"
        hashfoundry.io/job-type: "work-queue"
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.35
        command: ["/bin/sh"]
        args: ["-c", "for i in \$(seq 1 5); do echo 'Processing item '\$i; sleep 5; done; echo 'Queue processing completed'"]
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
        env:
        - name: JOB_TYPE
          value: "work-queue"
        - name: QUEUE_SIZE
          value: "5"
WORK_QUEUE_JOB_EOF
    
    # Example 4: Indexed Job (Kubernetes 1.21+)
    cat << INDEXED_JOB_EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: indexed-job
  namespace: jobs-examples
  labels:
    app.kubernetes.io/name: "indexed-job"
    hashfoundry.io/example: "indexed-job"
  annotations:
    hashfoundry.io/description: "Indexed job with completion index"
spec:
  completions: 4
  parallelism: 2
  completionMode: Indexed
  backoffLimit: 3
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "indexed-job"
        hashfoundry.io/job-type: "indexed"
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.35
        command: ["/bin/sh"]
        args: ["-c", "echo 'Processing index: '\$JOB_COMPLETION_INDEX; sleep 15; echo 'Index '\$JOB_COMPLETION_INDEX' completed'"]
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
        env:
        - name: JOB_TYPE
          value: "indexed"
INDEXED_JOB_EOF
    
    echo "✅ Basic Job examples created"
    echo
}

# Функция для создания CronJob examples
create_cronjob_examples() {
    echo "=== Creating CronJob Examples ==="
    
    # Example 1: Simple scheduled CronJob
    cat << SIMPLE_CRONJOB_EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: simple-cronjob
  namespace: jobs-examples
  labels:
    app.kubernetes.io/name: "simple-cronjob"
    hashfoundry.io/example: "simple-cronjob"
  annotations:
    hashfoundry.io/description: "Simple CronJob running every 5 minutes"
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        metadata:
          labels:
            app.kubernetes.io/name: "simple-cronjob"
            hashfoundry.io/job-type: "scheduled"
        spec:
          restartPolicy: Never
          containers:
          - name: worker
            image: busybox:1.35
            command: ["/bin/sh"]
            args: ["-c", "echo 'CronJob execution at: '\$(date); echo 'Performing scheduled task'; sleep 10; echo 'Scheduled task completed'"]
            resources:
              requests:
                cpu: "50m"
                memory: "64Mi"
              limits:
                cpu: "100m"
                memory: "128Mi"
            env:
            - name: JOB_TYPE
              value: "cronjob"
            - name: SCHEDULE
              value: "every-5-minutes"
SIMPLE_CRONJOB_EOF
    
    # Example 2: Backup CronJob
    cat << BACKUP_CRONJOB_EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-cronjob
  namespace: jobs-examples
  labels:
    app.kubernetes.io/name: "backup-cronjob"
    hashfoundry.io/example: "backup-cronjob"
  annotations:
    hashfoundry.io/description: "Backup CronJob running daily at 2 AM"
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 3
      activeDeadlineSeconds: 3600  # 1 hour timeout
      template:
        metadata:
          labels:
            app.kubernetes.io/name: "backup-cronjob"
            hashfoundry.io/job-type: "backup"
        spec:
          restartPolicy: Never
          containers:
          - name: backup-worker
            image: busybox:1.35
            command: ["/bin/sh"]
            args: ["-c", "echo 'Starting backup at: '\$(date); echo 'Backing up data...'; sleep 60; echo 'Backup completed at: '\$(date)"]
            resources:
              requests:
                cpu: "200m"
                memory: "256Mi"
              limits:
                cpu: "500m"
                memory: "512Mi"
            env:
            - name: JOB_TYPE
              value: "backup"
            - name: BACKUP_RETENTION
              value: "7"
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            emptyDir: {}
BACKUP_CRONJOB_EOF
    
    # Example 3: Cleanup CronJob
    cat << CLEANUP_CRONJOB_EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-cronjob
  namespace: jobs-examples
  labels:
    app.kubernetes.io/name: "cleanup-cronjob"
    hashfoundry.io/example: "cleanup-cronjob"
  annotations:
    hashfoundry.io/description: "Cleanup CronJob running weekly"
spec:
  schedule: "0 3 * * 0"  # Weekly on Sunday at 3 AM
  concurrencyPolicy: Replace
  successfulJobsHistoryLimit: 4
  failedJobsHistoryLimit: 2
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        metadata:
          labels:
            app.kubernetes.io/name: "cleanup-cronjob"
            hashfoundry.io/job-type: "cleanup"
        spec:
          restartPolicy: Never
          containers:
          - name: cleanup-worker
            image: busybox:1.35
            command: ["/bin/sh"]
            args: ["-c", "echo 'Starting cleanup at: '\$(date); echo 'Cleaning up old files...'; sleep 30; echo 'Cleanup completed at: '\$(date)"]
            resources:
              requests:
                cpu: "100m"
                memory: "128Mi"
              limits:
                cpu: "300m"
                memory: "256Mi"
            env:
            - name: JOB_TYPE
              value: "cleanup"
            - name: RETENTION_DAYS
              value: "30"
CLEANUP_CRONJOB_EOF
    
    # Example 4: Monitoring CronJob with different concurrency policy
    cat << MONITORING_CRONJOB_EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: monitoring-cronjob
  namespace: jobs-examples
  labels:
    app.kubernetes.io/name: "monitoring-cronjob"
    hashfoundry.io/example: "monitoring-cronjob"
  annotations:
    hashfoundry.io/description: "Monitoring CronJob with Allow concurrency policy"
spec:
  schedule: "*/2 * * * *"  # Every 2 minutes
  concurrencyPolicy: Allow
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 2
  jobTemplate:
    spec:
      backoffLimit: 1
      template:
        metadata:
          labels:
            app.kubernetes.io/name: "monitoring-cronjob"
            hashfoundry.io/job-type: "monitoring"
        spec:
          restartPolicy: Never
          containers:
          - name: monitor-worker
            image: busybox:1.35
            command: ["/bin/sh"]
            args: ["-c", "echo 'Monitoring check at: '\$(date); echo 'Checking system health...'; sleep 20; echo 'Health check completed'"]
            resources:
              requests:
                cpu: "50m"
                memory: "64Mi"
              limits:
                cpu: "100m"
                memory: "128Mi"
            env:
            - name: JOB_TYPE
              value: "monitoring"
            - name: CHECK_INTERVAL
              value: "2m"
MONITORING_CRONJOB_EOF
    
    echo "✅ CronJob examples created"
    echo
}

# Функция для создания Job monitoring tools
create_job_monitoring_tools() {
    echo "=== Creating Job Monitoring Tools ==="
    
    cat << JOB_MONITOR_EOF > job-monitoring-tools.sh
#!/bin/bash

echo "=== Job Monitoring Tools ==="
echo "Tools for monitoring Jobs and CronJobs"
echo

# Function to monitor job execution
monitor_job_execution() {
    local namespace=\${1:-""}
    local job_name=\${2:-""}
    
    if [ -n "\$namespace" ] && [ -n "\$job_name" ]; then
        echo "=== Monitoring Job: \$namespace/\$job_name ==="
        
        while true; do
            clear
            echo "Job Status for \$namespace/\$job_name"
            echo "================================="
            echo "Time: \$(date)"
            echo
            
            # Job details
            kubectl get job "\$job_name" -n "\$namespace" -o custom-columns="NAME:.metadata.name,COMPLETIONS:.spec.completions,SUCCESSFUL:.status.succeeded,ACTIVE:.status.active,FAILED:.status.failed,AGE:.metadata.creationTimestamp" 2>/dev/null
            echo
            
            # Job conditions
            echo "Job Conditions:"
            kubectl get job "\$job_name" -n "\$namespace" -o jsonpath='{.status.conditions}' 2>/dev/null | jq . || echo "No conditions available"
            echo
            
            # Job pods
            echo "Job Pods:"
            kubectl get pods -n "\$namespace" -l job-name="\$job_name" -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,NODE:.spec.nodeName" 2>/dev/null
            echo
            
            # Recent events
            echo "Recent Job Events:"
            kubectl get events -n "\$namespace" --field-selector involvedObject.name="\$job_name" --sort-by='.lastTimestamp' 2>/dev/null | tail -5
            echo
            
            # Check if job is completed
            JOB_STATUS=\$(kubectl get job "\$job_name" -n "\$namespace" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
            if [ "\$JOB_STATUS" = "True" ]; then
                echo "✅ Job completed successfully!"
                break
            fi
            
            JOB_FAILED=\$(kubectl get job "\$job_name" -n "\$namespace" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)
            if [ "\$JOB_FAILED" = "True" ]; then
                echo "❌ Job failed!"
                break
            fi
            
            echo "Press Ctrl+C to stop monitoring"
            sleep 10
        done
    else
        echo "Usage: monitor_job_execution <namespace> <job-name>"
        echo "Example: monitor_job_execution jobs-examples simple-job"
    fi
}

# Function to monitor CronJob execution
monitor_cronjob_execution() {
    local namespace=\${1:-""}
    local cronjob_name=\${2:-""}
    
    if [ -n "\$namespace" ] && [ -n "\$cronjob_name" ]; then
        echo "=== Monitoring CronJob: \$namespace/\$cronjob_name ==="
        
        while true; do
            clear
            echo "CronJob Status for \$namespace/\$cronjob_name"
            echo "========================================="
            echo "Time: \$(date)"
            echo
            
            # CronJob details
            kubectl get cronjob "\$cronjob_name" -n "\$namespace" -o custom-columns="NAME:.metadata.name,SCHEDULE:.spec.schedule,SUSPEND:.spec.suspend,ACTIVE:.status.active,LAST-SCHEDULE:.status.lastScheduleTime" 2>/dev/null
            echo
            
            # Active jobs
            echo "Active Jobs:"
            kubectl get jobs -n "\$namespace" -l cronjob="\$cronjob_name" --field-selector status.successful!=1 -o custom-columns="NAME:.metadata.name,COMPLETIONS:.spec.completions,SUCCESSFUL:.status.succeeded,ACTIVE:.status.active,AGE:.metadata.creationTimestamp" 2>/dev/null
            echo
            
            # Recent jobs
            echo "Recent Jobs (last 5):"
            kubectl get jobs -n "\$namespace" -l cronjob="\$cronjob_name" --sort-by='.metadata.creationTimestamp' -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Complete')].status,FAILED:.status.failed,AGE:.metadata.creationTimestamp" 2>/dev/null | tail -5
            echo
            
            # Recent events
            echo "Recent CronJob Events:"
            kubectl get events -n "\$namespace" --field-selector involvedObject.name="\$cronjob_name" --sort-by='.lastTimestamp' 2>/dev/null | tail -3
            echo
            
            echo "Press Ctrl+C to stop monitoring"
            sleep 15
        done
    else
        echo "Usage: monitor_cronjob_execution <namespace> <cronjob-name>"
        echo "Example: monitor_cronjob_execution jobs-examples simple-cronjob"
    fi
}

# Function to analyze job performance
analyze_job_performance() {
    echo "=== Job Performance Analysis ==="
    
    echo "1. All Jobs Status:"
    echo "=================="
    kubectl get jobs --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,COMPLETIONS:.spec.completions,SUCCESSFUL:.status.succeeded,FAILED:.status.failed,DURATION:.status.completionTime"
    echo
    
    echo "2. Failed Jobs:"
    echo "=============="
    kubectl get jobs --all-namespaces --field-selector status.successful!=1 -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,FAILED:.status.failed,REASON:.status.conditions[?(@.type=='Failed')].reason"
    echo
    
    echo "3. CronJob Status:"
    echo "================="
    kubectl get cronjobs --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,SCHEDULE:.spec.schedule,ACTIVE:.status.active,LAST-SCHEDULE:.status.lastScheduleTime,NEXT-SCHEDULE:.status.lastSuccessfulTime"
    echo
    
    echo "4. Job Resource Usage:"
    echo "====================="
    kubectl top pods --all-namespaces -l job-name --containers 2>/dev/null | head -10 || echo "Metrics server not available"
    echo
}

# Function to cleanup completed jobs
cleanup_completed_jobs() {
    local namespace=\${1:-""}
    local dry_run=\${2:-"true"}
    
    echo "=== Cleaning Up Completed Jobs ==="
    
    if [ -n "\$namespace" ]; then
        echo "Namespace: \$namespace"
        JOBS=\$(kubectl get jobs -n "\$namespace" --field-selector status.successful=1 -o jsonpath='{.items[*].metadata.name}')
    else
        echo "All namespaces"
        JOBS=\$(kubectl get jobs --all-namespaces --field-selector status.successful=1 -o jsonpath='{.items[*].metadata.name}')
    fi
    
    if [ -z "\$JOBS" ]; then
        echo "No completed jobs found"
        return 0
    fi
    
    echo "Completed jobs to clean up:"
    for job in \$JOBS; do
        echo "  - \$job"
    done
    echo
    
    if [ "\$dry_run" = "false" ]; then
        echo "Deleting completed jobs..."
        for job in \$JOBS; do
            if [ -n "\$namespace" ]; then
                kubectl delete job "\$job" -n "\$namespace"
            else
                kubectl delete job "\$job" --all-namespaces
            fi
        done
        echo "✅ Cleanup completed"
    else
        echo "Dry run mode - use 'cleanup_completed_jobs <namespace> false' to actually delete"
    fi
    echo
}

# Function to generate job report
generate_job_report() {
    echo "=== Generating Job Report ==="
    
    local report_file="job-report-\$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "HashFoundry HA Cluster Job Report"
        echo "================================="
        echo "Generated: \$(date)"
        echo ""
        
        echo "=== JOBS OVERVIEW ==="
        kubectl get jobs --all-namespaces
        echo ""
        
        echo "=== CRONJOBS OVERVIEW ==="
        kubectl get cronjobs --all-namespaces
        echo ""
        
        echo "=== FAILED JOBS ==="
        kubectl get jobs --all-namespaces --field-selector status.successful!=1
        echo ""
        
        echo "=== JOB PODS ==="
        kubectl get pods --all-namespaces -l job-name
        echo ""
        
        echo "=== RECENT JOB EVENTS ==="
        kubectl get events --all-namespaces --field-selector involvedObject.kind=Job --sort-by='.lastTimestamp' | tail -20
        echo ""
        
    } > "\$report_file"
    
    echo "✅ Job report generated: \$report_file"
    echo
}

# Main function
main() {
    case "\$1" in
        "monitor-job")
            monitor_job_execution "\$2" "\$3"
            ;;
        "monitor-cronjob")
            monitor_cronjob_execution "\$2" "\$3"
            ;;
        "analyze")
            analyze_job_performance
            ;;
        "cleanup")
            cleanup_completed_jobs "\$2" "\$3"
            ;;
        "report")
            generate_job_report
            ;;
        *)
            echo "Usage: \$0 [action] [options]"
            echo ""
            echo "Actions:"
            echo "  monitor-job <namespace> <job>       - Monitor job execution"
            echo "  monitor-cronjob <namespace> <cronjob> - Monitor cronjob execution"
            echo "  analyze                             - Analyze job performance"
            echo "  cleanup [namespace] [dry-run]       - Cleanup completed jobs"
            echo "  report                              - Generate job report"
            echo ""
            echo "Examples:"
            echo "  \$0 monitor-job jobs-examples simple-job"
            echo "  \$0 monitor-cronjob jobs-examples simple-cronjob"
            echo "  \$0 analyze"
            echo "  \$0 cleanup jobs-examples false"
            echo "  \$0 report"
            ;;
    esac
}

# Run main function
main "\$@"

JOB_MONITOR_EOF
    
    chmod +x job-monitoring-tools.sh
    
    echo "✅ Job monitoring tools created: job-monitoring-tools.sh"
    echo
}

# Основная функция
main() {
    case "$1" in
        "analyze")
            analyze_current_jobs_cronjobs
            ;;
        "job-examples")
            create_basic_job_examples
            ;;
        "cronjob-examples")
            create_cronjob_examples
            ;;
        "monitoring")
            create_job_monitoring_tools
            ;;
        "cleanup")
            # Cleanup examples
            kubectl delete namespace jobs-examples --grace-period=0 2>/dev/null || true
            echo "✅ Job examples cleaned up"
            ;;
        "all"|"")
            analyze_current_jobs_cronjobs
            create_basic_job_examples
            create_cronjob_examples
            create_job_monitoring_tools
            ;;
        *)
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  analyze           - Analyze current jobs and cronjobs"
            echo "  job-examples      - Create Job examples"
            echo "  cronjob-examples  - Create CronJob examples"
            echo "  monitoring        - Create monitoring tools"
            echo "  cleanup           - Cleanup examples"
            echo "  all               - Create all examples and tools (default)"
            echo ""
            echo "Examples:"
            echo "  $0 analyze"
            echo "  $0 job-examples"
            echo "  $0 monitoring"
            ;;
    esac
}

# Запустить основную функцию
main "$@"

EOF

chmod +x kubernetes-jobs-cronjobs-toolkit.sh

# Запустить создание Jobs и CronJobs toolkit
./kubernetes-jobs-cronjobs-toolkit.sh all
```

## 📋 **Job vs CronJob Comparison:**

### **Job Types:**

| **Type** | **Use Case** | **Completions** | **Parallelism** |
|----------|--------------|-----------------|-----------------|
| **One-time** | Разовая задача | 1 | 1 |
| **Parallel** | Параллельная обработка | N | M |
| **Work Queue** | Обработка очереди | Не указано | M |
| **Indexed** | Индексированные задачи | N | M |

### **CronJob Concurrency Policies:**

| **Policy** | **Behavior** | **Use Case** |
|------------|--------------|--------------|
| **Allow** | Разрешает параллельное выполнение | Мониторинг |
| **Forbid** | Запрещает параллельное выполнение | Бэкапы |
| **Replace** | Заменяет текущий Job новым | Очистка |

## 🎯 **Практические команды:**

### **Работа с Jobs и CronJobs:**
```bash
# Запустить Jobs toolkit
./kubernetes-jobs-cronjobs-toolkit.sh all

# Мониторинг Job
./job-monitoring-tools.sh monitor-job jobs-examples simple-job

# Мониторинг CronJob
./job-monitoring-tools.sh monitor-cronjob jobs-examples simple-cronjob
```

### **Управление Jobs:**
```bash
# Создать Job
kubectl create job my-job --image=busybox -- /bin/sh -c "echo hello; sleep 30; echo world"

# Проверить статус
kubectl get jobs
kubectl describe job my-job

# Удалить завершенные Jobs
kubectl delete jobs --field-selector status.successful=1
```

### **Управление CronJobs:**
```bash
# Создать CronJob
kubectl create cronjob my-cronjob --image=busybox --schedule="*/5 * * * *" -- /bin/sh -c "date; echo Hello from CronJob"

# Приостановить CronJob
kubectl patch cronjob my-cronjob -p '{"spec":{"suspend":true}}'

# Возобновить CronJob
kubectl patch cronjob my-cronjob -p '{"spec":{"suspend":false}}'
```

## 🔧 **Best
