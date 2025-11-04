# Config Deploy: azure-metrics-exporter

**English** | [Español](README_ES.md)

This repository contains the **per-environment configuration** for deploying `azure-metrics-exporter` on Kubernetes using ArgoCD.

## 🎯 What does this repo do?

Provides:
1. **Values per environment**: `values.infra.yaml`, `values.tst.yaml`, etc
2. **Secrets**: Environment-specific Azure credentials
3. **ArgoCD ApplicationSet**: Automated deployment via GitOps
4. **Helmfile**: Manual deployment orchestration (optional)

## 📂 File Structure

```
.
├── argo/
│   └── application-set.yaml      # ArgoCD ApplicationSet
├── secrets/
│   ├── env-secret.infra.yaml.example  # Secret example
│   └── env-secret.infra.yaml     # Real secrets (NOT COMMITTED)
├── values.infra.yaml             # Config for INFRA environment
├── values.prod.yaml.example      # Example for PROD
├── helmfile.yaml                 # Helm orchestrator
└── README.md                     # This documentation
```

## 🔄 Deployment Flow

```
┌──────────────────────────────────────────────────────────────┐
│ 1. Developer makes changes                                   │
│    - Edit values.infra.yaml                                  │
│    - Commit + Push to Git repository                         │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ 2. ArgoCD detects changes                                    │
│    - Polling every X minutes                                 │
│    - Or webhook from Git repository                          │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ 3. ArgoCD synchronizes                                       │
│    - Reads helm-chart-azure-metrics-exporter/                │
│    - Applies values.infra.yaml                               │
│    - Applies secrets/env-secret.infra.yaml                   │
│    - Deploys to monitoring namespace                         │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ 4. Kubernetes executes                                       │
│    - Pod with azure-metrics-exporter running                 │
│    - Exposing metrics at :8080/metrics                       │
│    - Prometheus scraping automatically                       │
└──────────────────────────────────────────────────────────────┘
```

## 🚀 Initial Setup

### 1. Clone the repository

```bash
git clone https://github.com/your-org/config-deploy-azure-metrics-exporter.git
cd config-deploy-azure-metrics-exporter
```

### 2. Configure secrets

```bash
# Copy the example
cp secrets/env-secret.infra.yaml.example secrets/env-secret.infra.yaml

# Edit with real credentials
vim secrets/env-secret.infra.yaml
```

**Secret content:**
```yaml
azure:
  tenantId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  clientId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  clientSecret: "your-real-secret"
  subscriptionId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 3. Configure Azure resources

Edit `values.infra.yaml` with your real Azure resources:

```bash
vim values.infra.yaml
```

**Example:**
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

**How to find resource names?**
See [Finding Azure Resources](./FINDING-AZURE-RESOURCES.md)

### 4. Apply secrets manually

```bash
kubectl create secret generic azure-exporter-infra-secret \
  --from-literal=tenantId="xxx" \
  --from-literal=clientId="xxx" \
  --from-literal=clientSecret="xxx" \
  --from-literal=subscriptionId="xxx" \
  -n monitoring
```

### 5. Deploy with ArgoCD

```bash
# Apply ApplicationSet
kubectl apply -f argo/application-set.yaml -n argocd

# Check status
argocd app get azure-exporter-infra

# View pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter
```

## 🔧 Manual Deployment with Helmfile

If you don't have ArgoCD:

```bash
# Install helmfile
# https://github.com/helmfile/helmfile

# Deploy to INFRA environment
helmfile -e infra sync

# Deploy to PROD environment  
helmfile -e prod sync
```

## 📝 Adding More Environments

1. Create `values.prod.yaml`:
```bash
cp values.infra.yaml values.prod.yaml
vim values.prod.yaml  # Edit with PROD resources
```

2. Create `secrets/env-secret.prod.yaml`:
```bash
cp secrets/env-secret.infra.yaml.example secrets/env-secret.prod.yaml
vim secrets/env-secret.prod.yaml  # Edit with PROD credentials
```

3. Update `argo/application-set.yaml`:
```yaml
generators:
  - list:
      elements:
        - env: infra
          cluster: https://kubernetes.default.svc
          namespace: monitoring
        - env: prod    # Add this
          cluster: https://kubernetes.prod.svc
          namespace: monitoring
```

## 🔐 Security with External Secrets (Recommended)

Instead of storing secrets as YAML files:

1. Store in Vault/AWS Secrets Manager
2. Use External Secrets Operator
3. Secrets sync automatically to Kubernetes

**Example with External Secrets:**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: azure-exporter-infra-secret
  namespace: monitoring
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: azure-exporter-infra-secret
  data:
    - secretKey: tenantId
      remoteRef:
        key: azure/exporter/infra
        property: tenantId
```

## 🐛 Troubleshooting

### ArgoCD not syncing

```bash
# View status
argocd app get azure-exporter-infra

# View differences
argocd app diff azure-exporter-infra
```

## 📚 References

- [azure-metrics-exporter GitHub](https://github.com/webdevops/azure-metrics-exporter)
- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [External Secrets Operator](https://external-secrets.io/)
