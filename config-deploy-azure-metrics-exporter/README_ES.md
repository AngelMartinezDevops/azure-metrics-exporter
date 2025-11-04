# Config Deploy: azure-metrics-exporter

[English](README.md) | **Español**

Este repositorio contiene la **configuración por entorno** para desplegar `azure-metrics-exporter` en Kubernetes usando ArgoCD.

## 🎯 ¿Qué hace este repo?

Proporciona:
1. **Values por entorno**: `values.infra.yaml`, `values.tst.yaml`, etc
2. **Secrets**: Credenciales Azure específicas de cada entorno
3. **ArgoCD ApplicationSet**: Despliegue automatizado vía GitOps
4. **Helmfile**: Orquestación de despliegues manuales (opcional)

## 📂 Estructura de archivos

```
.
├── argo/
│   └── application-set.yaml      # ArgoCD ApplicationSet
├── secrets/
│   ├── env-secret.infra.yaml.example  # Ejemplo de secrets
│   └── env-secret.infra.yaml     # Secrets reales (NO SE COMMITEA)
├── values.infra.yaml             # Config para entorno INFRA
├── values.tst.yaml               # Config para entorno TST
├── helmfile.yaml                 # Orquestador de Helm
└── README.md                     # Esta documentación
```

## 🔄 Flujo de despliegue

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
│ 3. ArgoCD sincroniza                                         │
│    - Lee helm-chart-azure-metrics-exporter/                  │
│    - Aplica values.infra.yaml                                │
│    - Aplica secrets/env-secret.infra.yaml                    │
│    - Despliega en namespace monitoring                       │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ 4. Kubernetes ejecuta                                        │
│    - Pod con azure-metrics-exporter corriendo                │
│    - Exponiendo métricas en :8080/metrics                    │
│    - Prometheus scrapeando automáticamente                   │
└──────────────────────────────────────────────────────────────┘
```

## 🚀 Setup inicial

### 1. Clone the repository

```bash
git clone https://github.com/your-org/config-deploy-azure-metrics-exporter.git
cd config-deploy-azure-metrics-exporter
```

### 2. Configurar secrets

```bash
# Copiar el ejemplo
cp secrets/env-secret.infra.yaml.example secrets/env-secret.infra.yaml

# Editar con credenciales reales
vim secrets/env-secret.infra.yaml
```

**Contenido del secret:**
```yaml
azure:
  tenantId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  clientId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  clientSecret: "tu-secret-real-aqui"
  subscriptionId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 3. Ajustar configuración por entorno

Edita `values.infra.yaml` para especificar:
- Resource Groups reales
- Nombres de recursos Azure
- Métricas específicas a extraer

**Ejemplo:**
```yaml
metricsConfig: |
  targets:
    - resourceType: "Microsoft.ApiManagement/service"
      resourceGroup: "rg-infra-services"  # ← Tu RG real
      resources: ["apim-infra-001"]       # ← Tu APIM real
      metrics:
        - name: Requests
```

### 4. Desplegar con ArgoCD

```bash
# Aplicar el ApplicationSet
kubectl apply -f argo/application-set.yaml -n argocd

# Verificar que se creó la Application
kubectl get applications -n argocd | grep azure-exporter

# Ver el estado
argocd app get azure-exporter-infra
```

### 5. Verificar el despliegue

```bash
# Ver pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter

# Ver logs
kubectl logs -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter -f

# Ver métricas
kubectl port-forward -n monitoring svc/azure-exporter-infra 8080:8080
curl http://localhost:8080/metrics
```

## 🔧 Despliegue manual (sin ArgoCD)

Si quieres probar sin ArgoCD, usa Helmfile:

```bash
# Instalar en entorno infra
helmfile -e infra sync

# Ver el estado
helmfile -e infra status

# Desinstalar
helmfile -e infra destroy
```

## 📝 Añadir nuevo entorno

Para añadir un entorno nuevo (por ejemplo, `prd`):

### 1. Crear archivo de values

```bash
cp values.infra.yaml values.prd.yaml
vim values.prd.yaml  # Ajustar para producción
```

### 2. Crear archivo de secrets

```bash
cp secrets/env-secret.infra.yaml.example secrets/env-secret.prd.yaml
vim secrets/env-secret.prd.yaml  # Credenciales de PRD
```

### 3. Actualizar helmfile.yaml

```yaml
environments:
  infra:
  tst:
  uat:
  prd:   # ← Añadir aquí
```

### 4. Actualizar ApplicationSet

```yaml
generators:
  - list:
      elements:
        - env: infra
          cluster: https://kubernetes.default.svc
        - env: prd    # ← Añadir aquí
          cluster: https://kubernetes.default.svc
```

### 5. Commit y push

```bash
git add values.prd.yaml argo/application-set.yaml helmfile.yaml
git commit -m "Add production environment"
git push origin master
```

ArgoCD detectará el cambio y desplegará automáticamente.

## 🔐 Migración a Vault (futuro)

Actualmente los secrets están en archivos YAML. Para migrar a Vault:

### 1. Instalar External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
```

### 2. Crear SecretStore

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: monitoring
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "azure-exporter"
```

### 3. Modificar el chart

En `helm-chart-azure-metrics-exporter/templates/`:
- Eliminar `secret.yaml`
- Añadir `external-secret.yaml`

### 4. Migrar credenciales

```bash
# Guardar en Vault
vault kv put secret/azure/metrics-exporter/infra \
  tenantId="xxx" \
  clientId="xxx" \
  clientSecret="xxx" \
  subscriptionId="xxx"
```

### 5. Eliminar archivos de secrets

```bash
rm secrets/env-secret.*.yaml
git commit -m "Migrate secrets to Vault"
```

## 🐛 Troubleshooting

### El pod no inicia

```bash
# Ver eventos
kubectl describe pod -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter

# Ver logs
kubectl logs -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter
```

**Problemas comunes:**
- Credenciales Azure incorrectas → Verificar `env-secret.*.yaml`
- Recursos Azure no existen → Verificar nombres en `values.*.yaml`
- Permisos insuficientes → El SP necesita rol "Monitoring Reader"

### No aparecen métricas en Prometheus

```bash
# Verificar que el ServiceMonitor existe
kubectl get servicemonitor -n monitoring

# Verificar que Prometheus lo detectó
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Ir a http://localhost:9090/targets
# Buscar azure-metrics-exporter
```

### ArgoCD no sincroniza

```bash
# Ver el estado de la app
argocd app get azure-exporter-infra

# Forzar sincronización
argocd app sync azure-exporter-infra

# Ver diferencias
argocd app diff azure-exporter-infra
```

## 📚 Referencias

- [azure-metrics-exporter GitHub](https://github.com/webdevops/azure-metrics-exporter)
- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [External Secrets Operator](https://external-secrets.io/)

