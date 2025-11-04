{{/*
Este archivo contiene "funciones" reutilizables en los templates
Son como funciones helper que evitan repetir código
*/}}

{{/*
Genera el nombre completo del deployment
Ejemplo: si el release se llama "azure-exporter-infra" → usa ese nombre
*/}}
{{- define "azure-metrics-exporter.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Genera el nombre del chart (usado en labels)
Ejemplo: azure-metrics-exporter-0.1.0
*/}}
{{- define "azure-metrics-exporter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Labels comunes que se aplican a todos los recursos
Se usan para identificar y filtrar recursos en K8s
*/}}
{{- define "azure-metrics-exporter.labels" -}}
helm.sh/chart: {{ include "azure-metrics-exporter.chart" . }}
{{ include "azure-metrics-exporter.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Labels de selección (usados para conectar Service con Deployment)
El Service usa estos labels para encontrar los pods
*/}}
{{- define "azure-metrics-exporter.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

