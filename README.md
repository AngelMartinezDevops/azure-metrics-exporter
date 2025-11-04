# Azure Metrics Exporter - Helm Chart & Deployment

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Helm](https://img.shields.io/badge/Helm-v3-blue.svg)](https://helm.sh)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.20+-326CE5.svg)](https://kubernetes.io/)

**English** | [Español](README_ES.md)

Export Azure Monitor metrics to Prometheus using [azure-metrics-exporter](https://github.com/webdevops/azure-metrics-exporter) with a production-ready Helm chart and GitOps deployment configuration.

## 🎯 Why This Project?

The native Azure Monitor integration in Grafana has limitations:
- **Limited filters**: Hard to filter by environment, resource group, or subscription
- **Complex correlation**: Difficult to correlate metrics between different Azure resources
- **Limited PromQL**: Can't leverage the full power of PromQL queries
- **Inconsistent labels**: Metrics don't have standard labels for easy filtering

This project solves these problems by:
- ✅ Exporting Azure metrics to Prometheus in standard format
- ✅ Adding consistent labels (subscription, resource_group, resource_name)
- ✅ Enabling powerful PromQL queries and correlations
- ✅ Creating reusable Grafana dashboards with dynamic variables
- ✅ Providing GitOps-ready deployment with ArgoCD

## 📦 Project Structure

This repository contains two main components following GitOps best practices:

```
azuremetrics/
├── helm-chart-azure-metrics-exporter/      # Helm Chart (HOW to deploy)
│   ├── Chart.yaml
│   ├── values.yaml                         # Default configuration
│   ├── templates/                          # Kubernetes resources
│   └── README.md
│
├── config-deploy-azure-metrics-exporter/   # Configuration (WHAT to deploy)
│   ├── values.infra.yaml                   # Environment-specific config
│   ├── helmfile.yaml                       # Helmfile for manual deploy
│   ├── argo/                               # ArgoCD ApplicationSet
│   ├── secrets/                            # Secret templates
│   └── README.md
│
└── docs/                                   # Documentation
    ├── GUIA-COMPLETA.md                    # Complete guide
    └── EXPLICACION-TECNICA.md              # Technical explanation
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (1.20+)
- Helm 3
- Azure subscription with resources to monitor
- Azure Service Principal with "Monitoring Reader" role

### 1. Create Azure Service Principal

```bash
# Login to Azure
az login

# Create Service Principal
az ad sp create-for-rbac \
  --name "sp-azure-metrics-exporter" \
  --role "Monitoring Reader" \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID

# Save the output:
# - appId → clientId
# - password → clientSecret
# - tenant → tenantId
```

### 2. Install with Helm

```bash
# Add credentials
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_SUBSCRIPTION_ID="your-subscription-id"

# Install chart
helm install azure-exporter ./helm-chart-azure-metrics-exporter \
  --set azure.tenantId=$AZURE_TENANT_ID \
  --set azure.clientId=$AZURE_CLIENT_ID \
  --set azure.clientSecret=$AZURE_CLIENT_SECRET \
  --set azure.subscriptionId=$AZURE_SUBSCRIPTION_ID \
  --namespace monitoring \
  --create-namespace
```

### 3. Verify Deployment

```bash
# Check pod status
kubectl get pods -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter

# Port-forward to access metrics
kubectl port-forward -n monitoring svc/azure-exporter 8080:8080

# View metrics
curl http://localhost:8080/metrics
```

### 4. Configure Prometheus

The chart includes a ServiceMonitor for Prometheus Operator. Prometheus will automatically start scraping metrics.

Verify in Prometheus:
```promql
azure_redis_connectedclients
azure_apim_requests_total
azure_sql_cpu_percent
```

## 📊 Supported Azure Resources

The chart comes pre-configured for common Azure resources:

- **API Management (APIM)**: Requests, Capacity, Duration
- **SQL Databases**: CPU, Memory, Storage, Connections
- **Redis Cache**: Connected clients, Memory usage, Cache hits/misses
- **Application Gateway**: Requests, Throughput, Backend status
- **Storage Accounts**: Capacity, Transactions, Ingress/Egress

All metrics include standard labels:
```
subscription_id="..."
resource_group="..."
resource_name="..."
location="australiaeast"
```

## 🎨 Example PromQL Queries

**Filter by resource group:**
```promql
azure_redis_connectedclients{resource_group="rg-production"}
```

**Correlation between resources:**
```promql
rate(azure_apim_requests_total[5m]) / azure_redis_connectedclients
```

**Aggregate by resource group:**
```promql
sum by (resource_group) (azure_redis_connectedclients)
```

**Dynamic variables in Grafana:**
```promql
azure_redis_connectedclients{resource_group=~"$resource_group"}
```

## 🔧 Configuration

### Basic Configuration

Edit `helm-chart-azure-metrics-exporter/values.yaml` to configure:
- Resource limits (CPU/Memory)
- ServiceMonitor settings
- Ingress configuration

### Per-Environment Configuration

Create environment-specific values files in `config-deploy-azure-metrics-exporter/`:
- `values.prod.yaml` - Production resources
- `values.staging.yaml` - Staging resources
- `values.dev.yaml` - Development resources

### Adding More Resources

Edit the `metricsConfig` section in your values file:

```yaml
metricsConfig: |
  targets:
    - resourceType: "Microsoft.Cache/redis"
      resourceGroup: "your-resource-group"
      resources: ["redis-instance-1", "redis-instance-2"]
      metrics:
        - name: connectedclients
          aggregations: ["Maximum"]
```

## 🎯 GitOps with ArgoCD

Deploy automatically using ArgoCD:

```bash
kubectl apply -f config-deploy-azure-metrics-exporter/argo/application-set.yaml
```

ArgoCD will:
- Monitor your Git repository
- Automatically sync changes
- Self-heal if manual changes are made
- Deploy to multiple environments

## 📚 Documentation

- [Helm Chart README](./helm-chart-azure-metrics-exporter/README.md) - Chart documentation
- [Config Deploy README](./config-deploy-azure-metrics-exporter/README.md) - Deployment guide
- [Finding Azure Resources](./config-deploy-azure-metrics-exporter/FINDING-AZURE-RESOURCES.md) - Azure CLI guide

## 🛠️ Troubleshooting

### Pod not starting

```bash
# Check pod status
kubectl describe pod -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter

# View logs
kubectl logs -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter
```

Common issues:
- **Authentication failed**: Check Service Principal credentials
- **Access denied**: Verify "Monitoring Reader" role is assigned
- **Resource not found**: Check resource names in configuration

### No metrics appearing

```bash
# Check ConfigMap
kubectl get configmap -n monitoring azure-exporter-config -o yaml

# Check metrics endpoint
kubectl port-forward -n monitoring svc/azure-exporter 8080:8080
curl http://localhost:8080/metrics | grep azure_
```

### Prometheus not scraping

```bash
# Verify ServiceMonitor exists
kubectl get servicemonitor -n monitoring

# Check Prometheus targets
# Open Prometheus UI → Status → Targets
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📖 Official Documentation

- [azure-metrics-exporter](https://github.com/webdevops/azure-metrics-exporter) - GitHub repository
- [Azure Monitor Metrics](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/metrics-supported) - Supported metrics list
- [Helm Documentation](https://helm.sh/docs/) - Helm user guide
- [Kubernetes Documentation](https://kubernetes.io/docs/) - Kubernetes concepts
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/) - GitOps with ArgoCD
- [Prometheus Operator](https://prometheus-operator.dev/) - Prometheus on Kubernetes
- [ServiceMonitor CRD](https://prometheus-operator.dev/docs/operator/design/#servicemonitor) - ServiceMonitor specification

## 🙏 Acknowledgments

- [azure-metrics-exporter](https://github.com/webdevops/azure-metrics-exporter) by webdevops
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [Helm](https://helm.sh/)
- [ArgoCD](https://argo-cd.readthedocs.io/)

## 📧 Contact

If you have questions or need help, feel free to open an issue.

---

**Made with ❤️ for the Kubernetes and Azure community**

