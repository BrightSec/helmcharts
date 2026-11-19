{{- define "ao-https-with-header.pinning" -}}
{{- if ne (toString .Values.clientCertPinning) "" -}}
{{- toString .Values.clientCertPinning -}}
{{- else if .Values.clientCA -}}
false
{{- else -}}
true
{{- end -}}
{{- end -}}

{{- define "ao-https-with-header.check" -}}
{{- $check := toString (default "ca" .Values.clientCertCheck) -}}
{{- if not (has $check (list "ca" "exact")) -}}
{{- fail (printf "clientCertCheck must be \"ca\" or \"exact\", got %q" $check) -}}
{{- end -}}
{{- if and (eq $check "exact") (not .Values.clientCA) -}}
{{- fail "clientCertCheck=exact needs clientCA with the accepted client certificates" -}}
{{- end -}}
{{- $check -}}
{{- end -}}
