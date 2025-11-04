# Helm Chart: azure-metrics-exporter

[English](README.md) | **Español**

Este Helm Chart despliega [azure-metrics-exporter](https://github.com/webdevops/azure-metrics-exporter) en Kubernetes para exportar métricas de recursos Azure a Prometheus.

## ¿Qué hace este chart?

Despliega una aplicación que:
1. Se conecta a Azure usando un Service Principal
2. Extrae métricas de recursos Azure (APIM, Database, Redis, Storage, etc)
3. Las expone en formato Prometheus en `/metrics`
4. Prometheus las scrapea automáticamente vía ServiceMonitor

## Estructura de archivos

```
.
├── Chart.yaml              # Metadatos del chart (nombre, versión)
├── values.yaml             # Valores por defecto
├── README.md               # Esta documentación
└── templates/
    ├── _helpers.tpl        # Funciones helper reutilizables
    ├── deployment.yaml     # Define cómo corre el pod
    ├── service.yaml        # Expone el pod internamente
    ├── configmap.yaml      # Configuración de métricas a extraer
    ├── secret.yaml         # Credenciales Azure
    └── servicemonitor.yaml # Integración con Prometheus
```

## ¿Cómo funciona cada componente?

### 1. Deployment (`deployment.yaml`)
Define cómo corre el pod:
- Qué imagen Docker usar
- Variables de entorno (credenciales Azure)
- Recursos CPU/Memoria
- Volúmenes montados

### 2. Service (`service.yaml`)
Expone el pod internamente en Kubernetes:
- Tipo: ClusterIP (solo accesible dentro del cluster)
- Puerto: 8080
- Conecta con los pods usando labels

### 3. ConfigMap (`configmap.yaml`)
Contiene la configuración de métricas:
- Qué recursos Azure monitorear
- Qué métricas específicas extraer
- Se monta como archivo en `/app/config.yaml`

### 4. Secret (`secret.yaml`)
Almacena credenciales Azure de forma segura:
- Tenant ID
- Client ID (Application ID)
- Client Secret
- Subscription ID

### 5. ServiceMonitor (`servicemonitor.yaml`)
Le dice a Prometheus que scrapee este servicio:
- Cada 60 segundos
- Endpoint: `/metrics`
- Puerto: 8080

## Configuración

### Credenciales Azure

Necesitas un Service Principal con permisos de lectura en los recursos a monitorear:

```yaml
azure:
  tenantId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  clientId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  clientSecret: "tu-secret-aqui"
  subscriptionId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Configuración de métricas

En `metricsConfig` defines qué recursos monitorear:

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

## Instalación

```bash
helm install azure-exporter . \
  --set azure.tenantId="xxx" \
  --set azure.clientId="xxx" \
  --set azure.clientSecret="xxx" \
  --set azure.subscriptionId="xxx" \
  --namespace monitoring \
  --create-namespace
```

## Personalización

### Cambiar recursos

Edita `values.yaml`:

```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### Habilitar Ingress

```yaml
ingress:
  enabled: true
  hosts:
    - host: azure-metrics.example.com
      paths:
        - path: /
          pathType: Prefix
```

### Configurar ServiceMonitor

```yaml
serviceMonitor:
  enabled: true
  interval: 60s
```

## Verificación

```bash
# Ver pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter

# Ver métricas
kubectl port-forward -n monitoring svc/azure-exporter 8080:8080
curl http://localhost:8080/metrics
```

## 📚 Más Información

- [README Principal](../README_ES.md)
- [Config Deploy](../config-deploy-azure-metrics-exporter/README_ES.md)

