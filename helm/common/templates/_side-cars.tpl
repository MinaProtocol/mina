### Mina Testnet side-car container TEMPLATES ###

# *** Watchman specifications ***

{{/*
Side-Car - Watchman: volume definition
*/}}
{{- define "sideCar.watchman.volume" }}
{{- if .watchman.enable }}
- name: {{ .watchman.volume_name }}
  emptyDir: {}
{{- end }}
{{- end }}


{{/*
Side-Car - Watchman: volume-mount definition
*/}}
{{- define "sideCar.watchman.volumeMount" }}
{{- if .watchman.enable }}
- name: {{ .watchman.volumeName }}
  mountPath: {{ .watchman.volumeMountPath }}
{{- end }}
{{- end }}

{{/*
Side-Car - Watchman: container life-cycle definition for post-start/pre-stop operations related to collecting Core dumps
*/}}
{{- define "sideCar.watchman.lifeCycleHook.coreDump" }}
{{- if .watchman.enable }}
lifecycle:
  postStart:
    exec:
      command: ["echo", "'{{ .watchman.volumeMountPath }}/core.%h.%e.%t' > /proc/sys/kernel/core_pattern"]
  preStop:
    exec:
      command: ["ls","-lah", "{{ .watchman.volumeMountPath }}"]
{{- end }}
{{- end }}

{{/*
Side-Car - Watchman: container definition
*/}}
{{- define "sideCar.watchman.containerSpec" }}
{{- if .watchman.enable }}
- name: watchman
  image: {{ .watchman.image }}
  args: {{ .watchman.command }}
  imagePullPolicy: Always
  volumeMounts:
{{- include "sideCar.watchman.volumeMount" . | indent 2 }}
{{- end }}
{{- end }}


{{/*
Side-Car - Resources: container definition
*/}}
{{- define "sideCar.resources.containerSpec" }}
{{- if .resources.enable }}
- name: resources
  image: {{ .resources.image }}
  args: {{ .resources.args }}
  imagePullPolicy: Always
  securityContext:
    privileged: true
  ports:
    - name: http-resources
      containerPort: 4000
      protocol: TCP
  resources:
    requests:
      memory: {{ .resources.memory | default "0.1G" }}
      cpu: {{ .resources.cpu | default "0.1" }}
    limits:
      memory: {{ .resources.memory | default "0.1G" }}
      cpu: {{ .resources.cpu | default "0.1" }}
{{- end }}
{{- end }}

{{/*
Side-Car - Resources: service definition
*/}}
{{- define "sideCar.resources.service" }}
{{- if .resources.enable }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}-resources
spec:
  type: ClusterIP
  publishNotReadyAddresses: true
  selector:
    app: {{ .name }}
  ports:
  - name: http-resources
    protocol: TCP
    port: 80
    targetPort: 4000
{{- end }}
{{- end }}

{{/*
Side-Car - common pod attributes
*/}}
{{- define "sideCar.podAttrs" }}
{{- if or .bpfDebugger.enable .resources.enable }}
shareProcessNamespace: true
runtimeClassName: {{ .bpfDebugger.runtime | default "kata-clh" }}
{{- end }}
{{- end }}

{{/*
Side-Car - BpfDebugger: container definition
*/}}
{{- define "sideCar.bpfDebugger.containerSpec" }}
{{- if .bpfDebugger.enable }}
- name: bpf-debugger
  image: {{ .bpfDebugger.image }}
  {{ if .bpfDebugger.args }}
  args: {{ .bpfDebugger.args }}
  {{ end }}
  imagePullPolicy: Always
  securityContext:
    privileged: true
  env:
    - name: RUST_LOG
      value: info
    - name: SERVER_PORT
      value: "80"
    - name: DEBUGGER_NAME
      value: "debugger"
  ports:
    - name: http-bpf-dbg
      containerPort: 80
      protocol: TCP
  resources:
    requests:
      memory: {{ .bpfDebugger.memory | default "4G" }}
      cpu: {{ .bpfDebugger.cpu | default "1" }}
    limits:
      memory: {{ .bpfDebugger.memory | default "4G" }}
      cpu: {{ .bpfDebugger.cpu | default "1" }}
  volumeMounts:
    - mountPath: /sys/kernel/debug
      name: sys-kernel-debug
  {{- if .bpfDebugger.restartMina }}
  lifecycle:
    postStart:
      exec:
        command: [ "sh", "-c", "PID=$(pgrep -fx coda-libp2p_helper); [ -z \"$PID\" ] || kill -TERM $PID" ]
  {{- end }}
{{- end }}
{{- end }}

{{/*
Side-Car - BpfDebugger: volume definition
*/}}
{{- define "sideCar.bpfDebugger.volume" }}
{{- if .bpfDebugger.enable }}
- name: sys-kernel-debug
  hostPath:
    path: /sys/kernel/debug
{{- end }}
{{- end }}

{{/*
Side-Car - BpfDebugger: BPF_ALIAS variable
*/}}
{{- define "sideCar.bpfDebugger.envVar" }}
{{- if .bpfDebugger.enable }}
- name: BPF_ALIAS
  value: auto-0.0.0.0
{{- end }}
{{- end }}

{{/*
Side-Car - BpfDebugger: service definition
*/}}
{{- define "sideCar.bpfDebugger.service" }}
{{- if .bpfDebugger.enable }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}-bpf-debugger
spec:
  type: ClusterIP
  selector:
    app: {{ .name }}
  ports:
  - name: http-bpf-debugger
    protocol: TCP
    port: 80
    targetPort: "http-bpf-dbg"
{{- end }}
{{- end }}


{{/*
Side-Car - LogService: Mina logs volume name
*/}}
{{define "sideCar.logs.minaLogsVolumeName" }}config-dir{{ end }}

{{/*
Side-Car - LogService: container
*/}}
{{- define "sideCar.logs.containerSpec" }}
{{- if .logs.enable }}
- name: logs
  image: {{ .logs.image }}
  imagePullPolicy: Always
  args:
  - --dir=/mina-logs
  - --address=0.0.0.0:81
  - --tar-file-prefix=$(NAMESPACE)-$(POD)-logs
  env:
  - name: POD
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
  ports:
  - name: http-logs
    protocol: TCP
    containerPort: 81
  volumeMounts:
  - mountPath: /mina-logs
    name: {{ template "sideCar.logs.minaLogsVolumeName" }}
  resources:
    requests:
      memory: {{ .logs.memory | default "0.1G" }}
      cpu: {{ .logs.cpu | default "0.1" }}
    limits:
      memory: {{ .logs.memory | default "0.1G" }}
      cpu: {{ .logs.cpu | default "0.1" }}
{{- end }}
{{- end }}

{{/*
Side-Car - LogService: volume definition
*/}}
{{- define "sideCar.logs.minaLogsVolume" }}
{{- if .logs.enable }}
- name: {{ template "sideCar.logs.minaLogsVolumeName" }}
  emptyDir: {}
{{- end }}
{{- end }}

{{/*
Side-Car - LogService: service definition
*/}}
{{- define "sideCar.logs.service" }}
{{- if .logs.enable }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}-logs
spec:
  type: ClusterIP
  selector:
    app: {{ .name }}
  ports:
  - name: http-logs
    protocol: TCP
    port: 80
    targetPort: "http-logs"
{{- end }}
{{- end }}
