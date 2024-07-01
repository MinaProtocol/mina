# ArgoCD installation, configuration and test-drive

**NOTE:** check the Issues to Resolve section at the end to understand current state.

## Installation with Helm
The community maintained Charts for [ArgoCD 5.42.2 are used](https://github.com/argoproj/argo-helm/tree/argo-cd-5.42.1)

## 1. Add repository
```bash
helm repo add argo https://argoproj.github.io/argo-helm 
```

### NOTE ABOUT CURRENT VERSION
This Chart uses the official one as dependency. In this way we can deploy in-house Secrets simultaneously.
Even-though the rest of the tutorial provides basic instructions to onboard clusters and repositories it is strongly recommended to leverage a secured Secrets Operations workflow for this.

In this PoC, we pre-deployed an External Secret Operator and onboarded baseline repos and credentials from a file (following structure proposed in ArgoCD for [SSH Repository Secrets](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#repositories)). See [`github-credentials.yaml`](./templates/github-credentials.yaml)

## 2. Create a `values.yaml` file
You can review the [default values for the release](https://github.com/argoproj/argo-helm/blob/argo-cd-5.42.1/charts/argo-cd/values.yaml).

**NOTE:** the `helmfile` plugin allows the deployment using, yes, helmfile. This is added as a sidecar to the `.repoServer`, and can be seen in the provided [`argocd.yaml`](./argocd.yaml) values file.

## 3. Deploy using `helm`
```bash
# check what's to be deployed
RELEASE="new-argo"
NAMESPACE="example"
VALUES="argocd.yaml"

# add --dry-run=client to check manifests without apply
helm diff upgrade --install $RELEASE argo/argo-cd --version 5.41.2 --namespace $NAMESPACE -f $VALUES
```

### Notes about default password
You can retrieve the initial auto-generated password from a newly created secret in `$NAMESPACE`:
```bash
kubectl get get secret argocd-initial-admin-secret -ojsonpath='{.data.password}'
```

Alternatively, use the `argocd` CLI tool:
```bash
# retrieve password
argocd admin initial-password -n argocd
```