{{/*
Release name
Usage: {{ include "voting-app.fullname" . }}-vote
*/}}
{{- define "voting-app.fullname" -}}
{{- .Release.Name }}
{{- end }}

{{/*
Common labels for all resources
*/}}
{{- define "voting-app.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
