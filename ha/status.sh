#!/bin/bash

# HashFoundry Infrastructure Status Check Script

set -e

# Load common functions
source "$(dirname "$0")/common-functions.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Function to check Terraform status
check_terraform_status() {
    echo ""
    echo "🏗️  Terraform Infrastructure Status"
    echo "=================================="
    
    if [ ! -f terraform/terraform.tfstate ]; then
        print_status "ERROR" "Terraform state file not found. Infrastructure not deployed."
        return 1
    fi
    
    print_status "OK" "Terraform state file exists"
    
    # Check if cluster exists in DigitalOcean
    if [ -f .env ]; then
        source .env
        if [ -n "$DO_TOKEN" ] && [ "$DO_TOKEN" != "your_digitalocean_api_token_here" ]; then
            doctl auth init -t $DO_TOKEN >/dev/null 2>&1
            
            if doctl kubernetes cluster get "$CLUSTER_NAME" >/dev/null 2>&1; then
                local cluster_status=$(doctl kubernetes cluster get "$CLUSTER_NAME" --format Status --no-header)
                if [ "$cluster_status" = "running" ]; then
                    print_status "OK" "Cluster '$CLUSTER_NAME' is running"
                else
                    print_status "WARNING" "Cluster '$CLUSTER_NAME' status: $cluster_status"
                fi
                
                # Check nodes
                local node_count=$(doctl kubernetes cluster get "$CLUSTER_NAME" --format NodePools --no-header | grep -o 'count:[0-9]*' | cut -d: -f2)
                print_status "INFO" "Cluster has $node_count nodes configured"
                
            else
                print_status "ERROR" "Cluster '$CLUSTER_NAME' not found in DigitalOcean"
                return 1
            fi
        else
            print_status "WARNING" "DO_TOKEN not configured, cannot check cluster status"
        fi
    else
        print_status "WARNING" ".env file not found, cannot check cluster status"
    fi
}

# Function to check Kubernetes status
check_kubernetes_status() {
    echo ""
    echo "🎯 Kubernetes Applications Status"
    echo "================================"
    
    # Check if kubectl is configured
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_status "ERROR" "kubectl not configured or cluster not accessible"
        return 1
    fi
    
    print_status "OK" "kubectl configured and cluster accessible"
    
    # Check nodes
    local ready_nodes=$(kubectl get nodes --no-headers | grep -c " Ready ")
    local total_nodes=$(kubectl get nodes --no-headers | wc -l)
    
    if [ "$ready_nodes" -eq "$total_nodes" ]; then
        print_status "OK" "All nodes ready ($ready_nodes/$total_nodes)"
    else
        print_status "WARNING" "Some nodes not ready ($ready_nodes/$total_nodes)"
    fi
    
    # Check ArgoCD namespace
    if kubectl get namespace argocd >/dev/null 2>&1; then
        print_status "OK" "ArgoCD namespace exists"
        
        # Check ArgoCD pods
        local argocd_pods_ready=$(kubectl get pods -n argocd --no-headers | grep -c " Running ")
        local argocd_pods_total=$(kubectl get pods -n argocd --no-headers | wc -l)
        
        if [ "$argocd_pods_ready" -eq "$argocd_pods_total" ]; then
            print_status "OK" "All ArgoCD pods running ($argocd_pods_ready/$argocd_pods_total)"
        else
            print_status "WARNING" "Some ArgoCD pods not running ($argocd_pods_ready/$argocd_pods_total)"
        fi
        
        # Check ArgoCD applications
        if kubectl get applications -n argocd >/dev/null 2>&1; then
            echo ""
            echo "📦 ArgoCD Applications:"
            kubectl get applications -n argocd --no-headers | while read line; do
                local app_name=$(echo $line | awk '{print $1}')
                local sync_status=$(echo $line | awk '{print $2}')
                local health_status=$(echo $line | awk '{print $3}')
                
                if [ "$sync_status" = "Synced" ] && [ "$health_status" = "Healthy" ]; then
                    print_status "OK" "$app_name: $sync_status, $health_status"
                elif [ "$sync_status" = "Synced" ]; then
                    print_status "WARNING" "$app_name: $sync_status, $health_status"
                else
                    print_status "ERROR" "$app_name: $sync_status, $health_status"
                fi
            done
        else
            print_status "WARNING" "No ArgoCD applications found"
        fi
        
    else
        print_status "ERROR" "ArgoCD namespace not found"
        return 1
    fi
    
    # Check ingress
    if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
        print_status "OK" "NGINX Ingress namespace exists"
        
        local ingress_pods_ready=$(kubectl get pods -n ingress-nginx --no-headers | grep -c " Running ")
        local ingress_pods_total=$(kubectl get pods -n ingress-nginx --no-headers | wc -l)
        
        if [ "$ingress_pods_ready" -eq "$ingress_pods_total" ]; then
            print_status "OK" "All NGINX Ingress pods running ($ingress_pods_ready/$ingress_pods_total)"
        else
            print_status "WARNING" "Some NGINX Ingress pods not running ($ingress_pods_ready/$ingress_pods_total)"
        fi
        
        # Check load balancer
        local lb_ip=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$lb_ip" ]; then
            print_status "OK" "Load Balancer IP: $lb_ip"
        else
            print_status "WARNING" "Load Balancer IP not assigned yet"
        fi
    else
        print_status "WARNING" "NGINX Ingress namespace not found"
    fi
}

# Function to show access information
show_access_info() {
    echo ""
    echo "🔗 Access Information"
    echo "===================="
    
    if kubectl get svc argocd-server -n argocd >/dev/null 2>&1; then
        print_status "INFO" "ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:80"
        print_status "INFO" "Then open: http://localhost:8080"
        
        if [ -f .env ]; then
            source .env
            print_status "INFO" "Username: admin"
            print_status "INFO" "Password: $ARGOCD_ADMIN_PASSWORD"
        fi
    fi
    
    # Check if ingress is available
    local lb_ip=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$lb_ip" ]; then
        echo ""
        print_status "INFO" "External access via Load Balancer:"
        print_status "INFO" "Add to /etc/hosts: $lb_ip argocd.hashfoundry.local"
        print_status "INFO" "Then access: https://argocd.hashfoundry.local"
    fi
}

# Function to show quick commands
show_quick_commands() {
    echo ""
    echo "🛠️  Quick Commands"
    echo "=================="
    echo "kubectl get nodes                           # Check cluster nodes"
    echo "kubectl get pods -A                         # Check all pods"
    echo "kubectl get applications -n argocd          # Check ArgoCD apps"
    echo "kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server  # ArgoCD logs"
    echo "kubectl port-forward svc/argocd-server -n argocd 8080:80        # Access ArgoCD UI"
    echo ""
    echo "doctl kubernetes cluster list               # List DO clusters"
    echo "doctl kubernetes cluster kubeconfig save $CLUSTER_NAME  # Update kubeconfig"
}

# Main function
main() {
    local check_terraform=false
    local check_kubernetes=false
    local show_help=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --terraform|-t)
                check_terraform=true
                shift
                ;;
            --kubernetes|-k)
                check_kubernetes=true
                shift
                ;;
            --all|-a)
                check_terraform=true
                check_kubernetes=true
                shift
                ;;
            --help|-h)
                show_help=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help=true
                shift
                ;;
        esac
    done
    
    if [ "$show_help" = true ]; then
        echo "HashFoundry Infrastructure Status Check"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -t, --terraform     Check Terraform infrastructure status"
        echo "  -k, --kubernetes    Check Kubernetes applications status"
        echo "  -a, --all          Check both Terraform and Kubernetes status"
        echo "  -h, --help         Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 --all           # Check everything"
        echo "  $0 --terraform     # Check only infrastructure"
        echo "  $0 --kubernetes    # Check only applications"
        exit 0
    fi
    
    # If no specific check requested, check all
    if [ "$check_terraform" = false ] && [ "$check_kubernetes" = false ]; then
        check_terraform=true
        check_kubernetes=true
    fi
    
    echo "🔍 HashFoundry Infrastructure Status Check"
    echo "=========================================="
    
    local terraform_ok=true
    local kubernetes_ok=true
    
    if [ "$check_terraform" = true ]; then
        if ! check_terraform_status; then
            terraform_ok=false
        fi
    fi
    
    if [ "$check_kubernetes" = true ]; then
        if ! check_kubernetes_status; then
            kubernetes_ok=false
        fi
    fi
    
    if [ "$kubernetes_ok" = true ]; then
        show_access_info
    fi
    
    show_quick_commands
    
    echo ""
    echo "📊 Overall Status"
    echo "================"
    
    if [ "$terraform_ok" = true ] && [ "$kubernetes_ok" = true ]; then
        print_status "OK" "All systems operational"
        exit 0
    elif [ "$terraform_ok" = true ] || [ "$kubernetes_ok" = true ]; then
        print_status "WARNING" "Some issues detected"
        exit 1
    else
        print_status "ERROR" "Multiple issues detected"
        exit 2
    fi
}

# Run main function with all arguments
main "$@"
