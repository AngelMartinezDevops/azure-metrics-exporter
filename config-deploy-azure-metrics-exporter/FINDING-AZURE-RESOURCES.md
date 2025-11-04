# Finding Azure Resources

**English** | [Español](COMO-ENCONTRAR-RECURSOS-AZURE_ES.md)

This document helps you discover which Azure resources exist in each environment to correctly fill out the `values.{env}.yaml` files.

## 🔍 Useful Azure CLI Commands

### 1. Login and Configuration

```bash
# Login to Azure
az login

# List available subscriptions
az account list --output table

# Select subscription
az account set --subscription "Your Subscription Name"
# or
az account set --subscription "00000000-0000-0000-0000-000000000000"
```

### 2. List Resource Groups

```bash
# List all Resource Groups
az group list --output table

# Filter by environment
az group list --query "[?starts_with(name, 'rg-prod')]" --output table
az group list --query "[?starts_with(name, 'rg-infra')]" --output table
az group list --query "[?starts_with(name, 'rg-staging')]" --output table
```

### 3. List Resources by Type

#### Redis Cache

```bash
# List all Redis instances
az redis list --output table

# View details of a specific Redis
az redis show --name redis-prod-shared --resource-group rg-prod-shared

# Filter by resource group
az redis list --resource-group rg-prod-shared --output table
```

#### Application Gateway

```bash
# List all Application Gateways
az network application-gateway list --output table

# View details
az network application-gateway show \
  --name agw-prod-001 \
  --resource-group rg-production
```

#### MySQL Databases

```bash
# List MySQL Flexible Servers
az mysql flexible-server list --output table

# View details
az mysql flexible-server show \
  --name mysql-prod-001 \
  --resource-group rg-production

# List databases on the server
az mysql flexible-server db list \
  --server-name mysql-prod-001 \
  --resource-group rg-production \
  --output table
```

#### Storage Accounts

```bash
# List Storage Accounts
az storage account list --output table

# View details
az storage account show \
  --name storageaccountprod001 \
  --resource-group rg-production
```

#### API Management (APIM)

```bash
# List APIM instances
az apim list --output table

# View details
az apim show \
  --name apim-prod-001 \
  --resource-group rg-production
```

### 4. List ALL Resources in a Resource Group

```bash
# View all resources in a RG
az resource list --resource-group rg-production --output table

# With more details (using jq)
az resource list --resource-group rg-production --output json | jq '.[] | {name: .name, type: .type}'
```

### 5. View Available Metrics for a Resource

```bash
# View which metrics are available for a specific resource
az monitor metrics list-definitions \
  --resource /subscriptions/SUBSCRIPTION_ID/resourceGroups/rg-production/providers/Microsoft.Cache/redis/redis-prod-001 \
  --output table

# Get the resource ID
az redis show --name redis-prod-001 --resource-group rg-production --query id -o tsv
```

## 📋 Script to Automatically Generate Configuration

You can create a script to automatically generate the `metricsConfig` configuration:

```bash
#!/bin/bash
# generate-metrics-config.sh

SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
ENV="prod"

echo "# Metrics for environment: $ENV"
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

**Usage:**
```bash
chmod +x generate-metrics-config.sh
./generate-metrics-config.sh > metrics-config-prod.yaml
```

## 🎯 Naming Pattern Example

Common naming patterns in Azure infrastructure:

| Resource | Pattern | Example PROD | Example INFRA |
|---------|--------|-------------|---------------|
| Resource Group | `rg-{env}-{stack}` | `rg-prod-shared` | `rg-infra-shared` |
| Redis | `redis-{env}-{stack}` | `redis-prod-shared` | `redis-infra-shared` |
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

## ✅ Checklist to Complete values.yaml

1. ☐ Login to Azure CLI
2. ☐ Select the correct subscription
3. ☐ List Resource Groups for the environment
4. ☐ For each RG, list resources:
   - ☐ Redis
   - ☐ Application Gateway
   - ☐ MySQL
   - ☐ Storage Accounts
   - ☐ APIM (if exists)
5. ☐ Copy exact names to `values.{env}.yaml`
6. ☐ Verify names match (no typos)
7. ☐ Test with a simple metric first
8. ☐ Expand to all needed metrics

## 🔗 References

- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)
- [Azure Monitor Metrics](https://docs.microsoft.com/en-us/azure/azure-monitor/essentials/metrics-supported)
- [Naming conventions](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)

