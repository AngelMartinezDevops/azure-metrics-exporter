# Cómo Encontrar los Recursos Azure Reales

[English](FINDING-AZURE-RESOURCES.md) | **Español**

Este documento te ayuda a descubrir qué recursos Azure existen en cada entorno para completar los archivos `values.{env}.yaml` correctamente.

## 🔍 Comandos útiles de Azure CLI

### 1. Login y configuración

```bash
# Login en Azure
az login

# List available subscriptions
az account list --output table

# Select subscription
az account set --subscription "Your Subscription Name"
# or
az account set --subscription "00000000-0000-0000-0000-000000000000"
```

### 2. Listar Resource Groups

```bash
# Listar todos los Resource Groups
az group list --output table

# Filtrar por entorno
az group list --query "[?starts_with(name, 'rg-prd')]" --output table
az group list --query "[?starts_with(name, 'rg-infra')]" --output table
az group list --query "[?starts_with(name, 'rg-tst')]" --output table
```

### 3. Listar recursos por tipo

#### REDIS Cache

```bash
# Listar todos los Redis
az redis list --output table

# Ver detalles de un Redis específico
az redis show --name redis-prd-shared --resource-group rg-prd-shared

# Filtrar por resource group
az redis list --resource-group rg-prd-shared --output table
```

#### Application Gateway

```bash
# Listar todos los Application Gateways
az network application-gateway list --output table

# Ver detalles
az network application-gateway show \
  --name agw-prd-shared-app \
  --resource-group rg-prd-shared
```

#### MySQL Databases

```bash
# Listar MySQL Flexible Servers
az mysql flexible-server list --output table

# Ver detalles
az mysql flexible-server show \
  --name mysql-prd-shared-01 \
  --resource-group rg-prd-shared

# Listar bases de datos en el servidor
az mysql flexible-server db list \
  --server-name mysql-prd-shared-01 \
  --resource-group rg-prd-shared \
  --output table
```

#### Storage Accounts

```bash
# Listar Storage Accounts
az storage account list --output table

# Ver detalles
az storage account show \
  --name storageaccountprod001 \
  --resource-group rg-production
```

#### API Management (APIM)

```bash
# Listar APIM
az apim list --output table

# Ver detalles
az apim show \
  --name apim-prd-shared \
  --resource-group rg-prd-shared
```

### 4. Listar TODOS los recursos de un Resource Group

```bash
# Ver todos los recursos de un RG
az resource list --resource-group rg-prd-shared --output table

# Con más detalles
az resource list --resource-group rg-prd-shared --output json | jq '.[] | {name: .name, type: .type}'
```

### 5. Ver métricas disponibles para un recurso

```bash
# Ver qué métricas están disponibles para un recurso específico
az monitor metrics list-definitions \
  --resource /subscriptions/SUBSCRIPTION_ID/resourceGroups/rg-prd-shared/providers/Microsoft.Cache/redis/redis-prd-shared \
  --output table

# Obtener el resource ID de un recurso
az redis show --name redis-prd-shared --resource-group rg-prd-shared --query id -o tsv
```

## 📋 Script para generar la configuración automáticamente

Puedes crear un script para generar la configuración de `metricsConfig` automáticamente:

```bash
#!/bin/bash
# generate-metrics-config.sh

SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
ENV="prod"

echo "# Métricas para entorno: $ENV"
echo ""

# Redis
echo "# REDIS"
for redis in $(az redis list --query "[].{name:name,rg:resourceGroup}" -o tsv | awk '{print $1","$2}'); do
  NAME=$(echo $redis | cut -d',' -f1)
  RG=$(echo $redis | cut -d',' -f2)
  if [[ $NAME == *"$ENV"* ]]; then
    echo "- resourceType: \"Microsoft.Cache/redis\""
    echo "  resourceGroup: \"$RG\""
    echo "  resources: [\"$NAME\"]"
    echo ""
  fi
done

# Application Gateway
echo "# APPLICATION GATEWAY"
for agw in $(az network application-gateway list --query "[].{name:name,rg:resourceGroup}" -o tsv | awk '{print $1","$2}'); do
  NAME=$(echo $agw | cut -d',' -f1)
  RG=$(echo $agw | cut -d',' -f2)
  if [[ $NAME == *"$ENV"* ]]; then
    echo "- resourceType: \"Microsoft.Network/applicationGateways\""
    echo "  resourceGroup: \"$RG\""
    echo "  resources: [\"$NAME\"]"
    echo ""
  fi
done

# MySQL
echo "# MYSQL"
for mysql in $(az mysql flexible-server list --query "[].{name:name,rg:resourceGroup}" -o tsv | awk '{print $1","$2}'); do
  NAME=$(echo $mysql | cut -d',' -f1)
  RG=$(echo $mysql | cut -d',' -f2)
  if [[ $NAME == *"$ENV"* ]]; then
    echo "- resourceType: \"Microsoft.DBforMySQL/flexibleServers\""
    echo "  resourceGroup: \"$RG\""
    echo "  resources: [\"$NAME\"]"
    echo ""
  fi
done

# Storage
echo "# STORAGE ACCOUNTS"
for st in $(az storage account list --query "[].{name:name,rg:resourceGroup}" -o tsv | awk '{print $1","$2}'); do
  NAME=$(echo $st | cut -d',' -f1)
  RG=$(echo $st | cut -d',' -f2)
  if [[ $NAME == *"$ENV"* ]]; then
    echo "- resourceType: \"Microsoft.Storage/storageAccounts\""
    echo "  resourceGroup: \"$RG\""
    echo "  resources: [\"$NAME\"]"
    echo ""
  fi
done
```

**Uso:**
```bash
chmod +x generate-metrics-config.sh
./generate-metrics-config.sh > metrics-config-prd.yaml
```

## 🎯 Patrón de nombres en tu infraestructura

Según tu Terraform, el patrón es:

| Recurso | Patrón | Ejemplo PRD | Ejemplo INFRA |
|---------|--------|-------------|---------------|
| Resource Group | `rg-{env}-{stack}` | `rg-prd-shared` | `rg-infra-shared` |
| Redis | `redis-{env}-{stack}` | `redis-prd-shared` | `redis-infra-shared` |
| MySQL | `mysql-{env}-{app}-01` | `mysql-prod-app1-01` | `mysql-infra-shared-01` |
| AGW | `agw-{env}-{number}` | `agw-prod-001` | `agw-infra-001` |
| Storage | `storage{env}{type}` | `storageprodbackup` | `storageinfrabackup` |
| APIM | `apim-{env}-{number}` | `apim-prod-001` | `apim-infra-001` |

**Common naming patterns:**
- `shared`: Shared resources
- `app1`: Application 1 resources
- `app2`: Application 2 resources
- `api`: API services
- `web`: Web applications

## ✅ Checklist para completar values.yaml

1. ☐ Hacer login en Azure CLI
2. ☐ Seleccionar la subscription correcta
3. ☐ Listar Resource Groups del entorno
4. ☐ Para cada RG, listar recursos:
   - ☐ Redis
   - ☐ Application Gateway
   - ☐ MySQL
   - ☐ Storage Accounts
   - ☐ APIM (si existe)
5. ☐ Copiar nombres exactos a `values.{env}.yaml`
6. ☐ Verificar que los nombres coinciden (no typos)
7. ☐ Probar con una métrica simple primero
8. ☐ Ampliar a todas las métricas necesarias

## 🔗 Referencias

- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)
- [Azure Monitor Metrics](https://docs.microsoft.com/en-us/azure/azure-monitor/essentials/metrics-supported)
- [Naming conventions](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)

