# Azure Metrics Exporter - Helm Chart & Despliegue

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Helm](https://img.shields.io/badge/Helm-v3-blue.svg)](https://helm.sh)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.20+-326CE5.svg)](https://kubernetes.io/)

[English](README.md) | **Español**

Exporta métricas de Azure Monitor a Prometheus usando [azure-metrics-exporter](https://github.com/webdevops/azure-metrics-exporter) con un Helm chart production-ready y configuración GitOps para despliegue.

## 🎯 ¿Por Qué Este Proyecto?

La integración nativa de Azure Monitor en Grafana tiene limitaciones:
- **Filtros limitados**: Difícil filtrar por entorno, resource group o subscription
- **Correlación compleja**: Difícil correlacionar métricas entre diferentes recursos Azure
- **PromQL limitado**: No se puede aprovechar todo el poder de las queries PromQL
- **Labels inconsistentes**: Las métricas no tienen labels estándar para filtrado fácil

Este proyecto resuelve estos problemas:
- ✅ Exportando métricas Azure a Prometheus en formato estándar
- ✅ Añadiendo labels consistentes (subscription, resource_group, resource_name)
- ✅ Habilitando queries PromQL potentes y correlaciones
- ✅ Creando dashboards Grafana reutilizables con variables dinámicas
- ✅ Proporcionando despliegue GitOps-ready con ArgoCD

## 📦 Estructura del Proyecto

Este repositorio contiene dos componentes principales siguiendo mejores prácticas GitOps:

```
azuremetrics/
├── helm-chart-azure-metrics-exporter/      # Helm Chart (CÓMO desplegar)
│   ├── Chart.yaml
│   ├── values.yaml                         # Configuración por defecto
│   ├── templates/                          # Recursos Kubernetes
│   └── README.md
│
├── config-deploy-azure-metrics-exporter/   # Configuración (QUÉ desplegar)
│   ├── values.infra.yaml                   # Configuración por entorno
│   ├── helmfile.yaml                       # Helmfile para despliegue manual
│   ├── argo/                               # ArgoCD ApplicationSet
│   ├── secrets/                            # Templates de secrets
│   └── README.md
```

## 🚀 Inicio Rápido

### Prerequisitos

- Cluster Kubernetes (1.20+)
- Helm 3
- Subscription Azure con recursos a monitorear
- Azure Service Principal con rol "Monitoring Reader"

### 1. Crear Service Principal de Azure

```bash
# Login en Azure
az login

# Crear Service Principal
az ad sp create-for-rbac \
  --name "sp-azure-metrics-exporter" \
  --role "Monitoring Reader" \
  --scopes /subscriptions/TU_SUBSCRIPTION_ID

# Guardar el output:
# - appId → clientId
# - password → clientSecret
# - tenant → tenantId
```

### 2. Instalar con Helm

```bash
# Añadir credenciales
export AZURE_TENANT_ID="tu-tenant-id"
export AZURE_CLIENT_ID="tu-client-id"
export AZURE_CLIENT_SECRET="tu-client-secret"
export AZURE_SUBSCRIPTION_ID="tu-subscription-id"

# Instalar chart
helm install azure-exporter ./helm-chart-azure-metrics-exporter \
  --set azure.tenantId=$AZURE_TENANT_ID \
  --set azure.clientId=$AZURE_CLIENT_ID \
  --set azure.clientSecret=$AZURE_CLIENT_SECRET \
  --set azure.subscriptionId=$AZURE_SUBSCRIPTION_ID \
  --namespace monitoring \
  --create-namespace
```

### 3. Verificar Despliegue

```bash
# Ver estado de los pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter

# Port-forward para acceder a las métricas
kubectl port-forward -n monitoring svc/azure-exporter 8080:8080

# Ver métricas
curl http://localhost:8080/metrics
```

### 4. Configurar Prometheus

El chart incluye un ServiceMonitor para Prometheus Operator. Prometheus comenzará automáticamente a scrapear métricas.

Verificar en Prometheus:
```promql
azure_redis_connectedclients
azure_apim_requests_total
azure_sql_cpu_percent
```

## 📊 Recursos Azure Soportados

El chart viene pre-configurado para recursos Azure comunes:

- **API Management (APIM)**: Requests, Capacity, Duration
- **SQL Databases**: CPU, Memoria, Storage, Conexiones
- **Redis Cache**: Clientes conectados, Uso de memoria, Cache hits/misses
- **Application Gateway**: Requests, Throughput, Estado backend
- **Storage Accounts**: Capacidad, Transacciones, Ingress/Egress

Todas las métricas incluyen labels estándar:
```
subscription_id="..."
resource_group="..."
resource_name="..."
location="australiaeast"
```

## 🎨 Ejemplos de Queries PromQL

**Filtrar por resource group:**
```promql
azure_redis_connectedclients{resource_group="rg-production"}
```

**Correlación entre recursos:**
```promql
rate(azure_apim_requests_total[5m]) / azure_redis_connectedclients
```

**Agregar por resource group:**
```promql
sum by (resource_group) (azure_redis_connectedclients)
```

**Variables dinámicas en Grafana:**
```promql
azure_redis_connectedclients{resource_group=~"$resource_group"}
```

## 🔧 Configuración

### Configuración Básica

Editar `helm-chart-azure-metrics-exporter/values.yaml` para configurar:
- Límites de recursos (CPU/Memoria)
- Configuración ServiceMonitor
- Configuración Ingress

### Configuración por Entorno

Crear archivos de values específicos por entorno en `config-deploy-azure-metrics-exporter/`:
- `values.prod.yaml` - Recursos de producción
- `values.staging.yaml` - Recursos de staging
- `values.dev.yaml` - Recursos de desarrollo

### Añadir Más Recursos

Editar la sección `metricsConfig` en tu archivo de values:

```yaml
metricsConfig: |
  targets:
    - resourceType: "Microsoft.Cache/redis"
      resourceGroup: "tu-resource-group"
      resources: ["redis-instance-1", "redis-instance-2"]
      metrics:
        - name: connectedclients
          aggregations: ["Maximum"]
```

## 🎯 GitOps con ArgoCD

Desplegar automáticamente usando ArgoCD:

```bash
kubectl apply -f config-deploy-azure-metrics-exporter/argo/application-set.yaml
```

ArgoCD:
- Monitorizará tu repositorio Git
- Sincronizará cambios automáticamente
- Auto-sanará si se hacen cambios manuales
- Desplegará en múltiples entornos

## 📚 Documentación

- [README Helm Chart](./helm-chart-azure-metrics-exporter/README_ES.md) - Documentación del chart
- [README Config Deploy](./config-deploy-azure-metrics-exporter/README_ES.md) - Guía de despliegue
- [Encontrar Recursos Azure](./config-deploy-azure-metrics-exporter/COMO-ENCONTRAR-RECURSOS-AZURE_ES.md) - Guía Azure CLI

## 🛠️ Troubleshooting

### Pod no inicia

```bash
# Ver estado del pod
kubectl describe pod -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter

# Ver logs
kubectl logs -n monitoring -l app.kubernetes.io/name=azure-metrics-exporter
```

Problemas comunes:
- **Authentication failed**: Verificar credenciales del Service Principal
- **Access denied**: Verificar que el rol "Monitoring Reader" está asignado
- **Resource not found**: Verificar nombres de recursos en la configuración

### No aparecen métricas

```bash
# Ver ConfigMap
kubectl get configmap -n monitoring azure-exporter-config -o yaml

# Verificar endpoint de métricas
kubectl port-forward -n monitoring svc/azure-exporter 8080:8080
curl http://localhost:8080/metrics | grep azure_
```

### Prometheus no scrapea

```bash
# Verificar que existe el ServiceMonitor
kubectl get servicemonitor -n monitoring

# Verificar targets de Prometheus
# Abrir Prometheus UI → Status → Targets
```

## 🤝 Contribuir

¡Las contribuciones son bienvenidas! No dudes en enviar un Pull Request.

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## 📖 Documentación Oficial

- [azure-metrics-exporter](https://github.com/webdevops/azure-metrics-exporter) - Repositorio GitHub
- [Azure Monitor Metrics](https://learn.microsoft.com/es-es/azure/azure-monitor/essentials/metrics-supported) - Lista de métricas soportadas
- [Documentación Helm](https://helm.sh/docs/) - Guía de usuario Helm
- [Documentación Kubernetes](https://kubernetes.io/docs/) - Conceptos de Kubernetes
- [Documentación ArgoCD](https://argo-cd.readthedocs.io/) - GitOps con ArgoCD
- [Prometheus Operator](https://prometheus-operator.dev/) - Prometheus en Kubernetes
- [ServiceMonitor CRD](https://prometheus-operator.dev/docs/operator/design/#servicemonitor) - Especificación ServiceMonitor

## 🙏 Agradecimientos

- [azure-metrics-exporter](https://github.com/webdevops/azure-metrics-exporter) por webdevops
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [Helm](https://helm.sh/)
- [ArgoCD](https://argo-cd.readthedocs.io/)

## 📧 Contacto

Si tienes preguntas o necesitas ayuda, no dudes en abrir un issue.

---

**Hecho con ❤️ para la comunidad Kubernetes y Azure**

