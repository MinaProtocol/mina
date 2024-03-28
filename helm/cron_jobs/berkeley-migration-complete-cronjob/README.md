# Berkeley Migration CronJobs
This Helm Chart aims to ease the process of scripting the Mina mainnet migration replayers by isolating the script from the Kubernetes manifests.

The way it works can be summarized in the following items:
1. A Kubernetes Secret with the contents of `.Values.gcloudKeyfileRef` is created. It essentially retrieves the secret stored in GCP Secret Manager containing a valid `gcloud-keyfile.json`. This Secret will be mounted at `/gcloud/keyfile.json` on all `replayers` containers.
2. As many CronJobs are created as entries in the `.Values.replayers` list.
   1. A Kubernetes Secret called `{{ .Values.replayers.[*].script.secretName }}` is created with the contents of `{{ .Values.replayers.[*].script.scriptName }}` and mounted at each `replayer` container at `/scripts/{{ .Values.replayers.[*].scriptName }}`
3. Replayers have the following entrypoint: `/bin/bash -c /scripts/{{ .Values.replayers.[*].scriptName }}`
4. These are deployed using `gitops-infratructure`. But may also be deployed from a user environment using [`helm-secrets`](https://github.com/jkroepke/helm-secrets/wiki/Installation) (with `vals`) and sufficient authz in GCP to read GCP Secret Manager.

# Deployment
These CronJobs are deployed using ArgoCD. Refer to [GitOps-Infrastructure repository](https://github.com/o1-labs/gitops-infrastructure) for **platform** configurations.

# (Optional, requires authz) Deploy the CronJobs from your workstation
As manifests secure secrets using GCP Secrets Manager, `helm-secrets` plugin must be used to either deploy or check the rendered manifests (e.g., via `helm template`). To achieve this [install helm-secrets plugin](https://github.com/jkroepke/helm-secrets/wiki/Installation) and either:

#### a. Check manifests
```bash
# at mina/helm/cron_jobs/replayer-cronjobs
helm secrets --evaluate-templates template . -f values.yaml

# decode the evaluated templates by (values are shown in b64, though)
helm secrets --evaluate-templates --evaluate-templates-decode-secrets template . -f values.yaml
```

#### b. Deploy Chart
```bash
NAME=mainnet-replayer
NAMESPACE=my-namespace
helm secrets --evaluate-templates upgrade --install $NAME . -f values.yaml --namespace $NAMESPACE
```
You can perform this operation every time you change a value in the Chart or update the scripts under [`files`](./files/).

### Notes
- Some `values.yaml` are considered global (e.g., `.Values.image`) and are referenced in each `replayer` using [YAML anchors](https://helm.sh/docs/chart_template_guide/yaml_techniques/#yaml-anchors).
- An Example script [`test-run.sh`](./files/test-run.sh) is included so a debugging `replayer` can be launched. It essentially performs the same package installations as e.g., [`mainnet-migrated.sh`](./files/mainnet-migrated.sh) but with a `sleep 3600` instruction at the end. If you want to try it, **simply uncomment the `test-run` entry under `.Values.replayers`.**
