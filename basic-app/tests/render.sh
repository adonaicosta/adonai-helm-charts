#!/usr/bin/env bash
# Smoke test for the bits with real logic: env key refs, envFrom, keda, extraObjects.
# Usage: ./tests/render.sh   (from the chart dir)
set -euo pipefail
cd "$(dirname "$0")/.."

render() { helm template myapp . "$@"; }
has() { grep -qF -- "$1" <<<"$OUT" || { echo "FAIL: missing '$1'"; exit 1; }; }
hasnt() { grep -qF -- "$1" <<<"$OUT" && { echo "FAIL: unexpected '$1'"; exit 1; }; :; }

helm lint . -f tests/values-full.yaml >/dev/null

OUT=$(render -f tests/values-full.yaml)
yq -e 'true' >/dev/null <<<"$OUT"                     # every doc parses
has "kind: ScaledObject"
has "kind: TriggerAuthentication"                     # extraObjects: map form
has "name: myapp-extra"                               # extraObjects: string form + tpl
has "name: my-trigger-auth"                           # tpl inside extraObjects
hasnt "kind: HorizontalPodAutoscaler"                 # keda replaces hpa
has "name: myapp-config-env-named-gen"                # 2 generated cms, no doc collision
has "name: myapp-config-env-1"
has "key: log.level"                                  # keys as map -> rename
has "key: K2"                                         # keys as list
[[ $(yq -e 'select(.kind=="Secret") | .data.PORT' <<<"$OUT") == "ODA4MA==" ]]  # int values b64
# entries carrying `keys` must not be imported wholesale via envFrom
[[ $(yq -e 'select(.kind=="Deployment") | .spec.template.spec.containers[0].envFrom
            | map(.configMapRef.name // .secretRef.name) | join(",")' <<<"$OUT") \
   == "whole-cm,myapp-config-env-1,myapp-config-env-named-gen,whole-secret,myapp-secret-env-1" ]]

OUT=$(render --set autoscaling.enabled=true)
has "kind: HorizontalPodAutoscaler"

OUT=$(render --set envFrom=null)                      # no envFrom -> no empty keys
hasnt "envFrom:"
hasnt "env:"

! render --set autoscaling.enabled=true --set autoscaling.type=keda 2>/dev/null   # triggers required

OUT=$(render --set serviceAccount.create=true --set serviceAccount.name=mysa \
             --set storage.enabled=true --set storage.mountPath= \
             --set terminationGracePeriodSeconds=10)
has "kind: ServiceAccount"
has "serviceAccountName: mysa"
has "terminationGracePeriodSeconds: 10"
has "claimName: myapp-data"                           # empty mountPath: volume/PVC still created
hasnt "mountPath: /data"                              # ...but not mounted in the main container

OUT=$(render --set-json 'startupProbe={"httpGet":{"path":"/livez","port":8081}}' \
             --set-json 'extraContainerPorts=[{"name":"health","containerPort":8081,"protocol":"TCP"}]')
yq -e 'true' >/dev/null <<<"$OUT"
has "startupProbe:"
has "name: health"
OUT=$(render --set containerPort=0 \
             --set-json 'extraContainerPorts=[{"name":"health","containerPort":8081,"protocol":"TCP"}]')
has "containerPort: 8081"                             # extra ports render even without main port
hasnt "containerPort: 8080"
OUT=$(render --set containerPort=0)                   # no ports at all -> key omitted
[[ $(yq 'select(.kind=="Deployment") | .spec.template.spec.containers[0] | has("ports")' <<<"$OUT") == "false" ]]

echo "ok"
