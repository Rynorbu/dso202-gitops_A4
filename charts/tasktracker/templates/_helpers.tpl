{{/*
=============================================================================
File        : charts/tasktracker/templates/_helpers.tpl
Assignment  : DSO202 Assignment 4 - GitOps delivery with Argo CD
Descriptor  : 3.2
Purpose     : Named templates shared by every template (names, labels,
              Service host names, required-value checks). From Assignment 3,
              renamed task-tracker -> tasktracker.
=============================================================================
*/}}

{{/* tasktracker.name: chart name, or nameOverride. */}}
{{- define "tasktracker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* tasktracker.fullname: base name of every object ("tasktracker" via fullnameOverride). */}}
{{- define "tasktracker.fullname" -}}
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

{{/* tasktracker.chart: "<name>-<version>" for the helm.sh/chart label. */}}
{{- define "tasktracker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* tasktracker.environment: fails the render when no environment is given. */}}
{{- define "tasktracker.environment" -}}
{{- required "global.environment must be set (dev or staging) in environments/<env>/values.yaml" .Values.global.environment }}
{{- end }}

{{/* tasktracker.secretName: C3 - name of the existing Secret created from a SealedSecret. */}}
{{- define "tasktracker.secretName" -}}
{{- required "existingSecret must be set (tasktracker-credentials) - the chart never renders a Secret" .Values.existingSecret }}
{{- end }}

{{/* tasktracker.selectorLabels: stable labels - never add changing values here. */}}
{{- define "tasktracker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tasktracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* tasktracker.labels: the full recommended label set. */}}
{{- define "tasktracker.labels" -}}
helm.sh/chart: {{ include "tasktracker.chart" . }}
{{ include "tasktracker.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: task-tracker
dso202/environment: {{ include "tasktracker.environment" . | quote }}
{{- end }}

{{/* Service host names - used by the ConfigMap and the smoke test so DNS names always match. */}}
{{- define "tasktracker.dbHost" -}}
{{ include "tasktracker.fullname" . }}-db
{{- end }}
{{- define "tasktracker.backendHost" -}}
{{ include "tasktracker.fullname" . }}-backend
{{- end }}
{{- define "tasktracker.frontendHost" -}}
{{ include "tasktracker.fullname" . }}-frontend
{{- end }}
