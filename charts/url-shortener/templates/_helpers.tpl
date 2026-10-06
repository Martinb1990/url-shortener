{{- define "shortener.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shortener.labels" -}}
app.kubernetes.io/part-of: url-shortener
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/* Selector labels for a component: include "shortener.selector" (list . "app") */}}
{{- define "shortener.selector" -}}
{{- $ctx := index . 0 -}}
app.kubernetes.io/name: {{ index . 1 }}
app.kubernetes.io/instance: {{ $ctx.Release.Name }}
{{- end -}}

{{/* Restricted-profile container security context, shared by all workloads. */}}
{{- define "shortener.containerSecurity" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
capabilities:
  drop: ["ALL"]
seccompProfile:
  type: RuntimeDefault
{{- end -}}
