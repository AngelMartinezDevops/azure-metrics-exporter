# Helm Chart: azure-metrics-exporter

**English** | [Español](README_ES.md)

This Helm Chart deploys [azure-metrics-exporter](https://github.com/webdevops/azure-metrics-exporter) on Kubernetes to export Azure resource metrics to Prometheus.

## What does this chart do?

Deploys an application that:
1. Connects to Azure using a Service Principal
2. Extracts metrics from Azure resources (APIM, Database, Redis, Storage, etc)
3. Exposes them in Prometheus format at `/metrics`
4. Prometheus automatically scrapes them via ServiceMonitor

## File Structure

```
.
├── Chart.yaml              # Chart metadata (name, version)
├── values.yaml             # Default values
├── README.md               # This documentation
└── templates/
    ├── _helpers.tpl        # Reusable helper functions
    ├── deployment.yaml     # Defines how the pod runs
    ├── service.yaml        # Exposes the pod internally
    ├── configmap.yaml      # Metrics configuration
    ├── secret.yaml         # Azure credentials
    └── servicemonitor.yaml # Prometheus integration
```

## How does each component work?

### 1. Deployment (`deployment.yaml`)
Defines how the pod runs:
- Which Docker image to use
- Environment variables (Azure credentials)
- CPU/Memory resources
- Mounted volumes

### 2. Service (`service.yaml`)
Exposes the pod internally in Kubernetes:
- Type: ClusterIP (only accessible within the cluster)
- Port: 8080
- Connects to pods using labels

### 3. ConfigMap (`configmap.yaml`)
Contains the metrics configuration:
- Which Azure resources to monitor
- Which specific metrics to extract
- Mounted as a file at `/app/config.yaml`

### 4. Secret (`secret.yaml`)
Stores Azure credentials securely:
- Tenant ID
- Client ID (Application ID)
- Client Secret
- Subscription ID

### 5. ServiceMonitor (`servicemonitor.yaml`)
Tells Prometheus to scrape this service:
- Every 60 seconds
- Endpoint: `/metrics`
- Port: 8080

## Configuration

### Azure Credentials

You need a Service Principal with read permissions on the resources to monitor:

```yaml
azure:
  tenantId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  clientId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  clientSecret: "your-secret-here"
  subscriptionId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Metrics Configuration

In `metricsConfig` you define which resources to monitor:

```yaml
metricsConfig: |
  targets:
    - resourceType: "Microsoft.Cache/redis"
      resourceGroup: "rg-production"
      resources: ["redis-prod-001"]
      metrics:
        - name: connectedclients
          aggregations: ["Maximum"]
```

## Installation

```bash
helm install azure-exporter . \
  --set azure.tenantId="xxx" \
  --set azure.clientId="xxx" \
  --set azure.clientSecret="xxx" \
  --set azure.subscriptionId="xxx" \
  --namespace monitoring \
  --create-namespace
```

## Customization

### Change Resources

Edit `values.yaml`:

```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### Enable Ingress

```yaml
ingress:
  enabled: true
  hosts:
    - host: azure-metrics.example.com
      paths:
        - path: /
          pathType: Prefix
```

### Configure ServiceMonitor

```yaml
serviceMonitor:
  enabled: true
  interval: 60s
```

## Verification

```bash
# View pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter

# View metrics
kubectl port-forward -n monitoring svc/azure-exporter 8080:8080
curl http://localhost:8080/metrics
```

## 📚 More Information

- [Main README](../README.md)
- [Config Deploy](../config-deploy-azure-metrics-exporter/README.md)
