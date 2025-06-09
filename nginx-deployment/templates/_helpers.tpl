{{/* Chart helpers for nginx-deployment */}}

{{- define "nginx-deployment.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "nginx-deployment.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{-   .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{-   printf "%s-%s" (include "nginx-deployment.name" .) .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "nginx-deployment.labels" -}}
app.kubernetes.io/name:       {{ include "nginx-deployment.name" . }}
helm.sh/chart:                {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/instance:   {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "nginx-deployment.selectorLabels" -}}
app.kubernetes.io/name:     {{ include "nginx-deployment.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
