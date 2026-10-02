{{- define "python-app.name" -}}
python-app
{{- end }}

{{- define "python-app.fullname" -}}
{{ include "python-app.name" . }}
{{- end }}
