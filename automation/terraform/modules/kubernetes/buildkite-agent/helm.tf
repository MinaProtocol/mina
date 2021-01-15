provider kubernetes {
  alias = "bk_deploy"
  config_path = "~/.kube/config"
  config_context  = var.k8s_context
}

provider helm {
  alias = "bk_deploy"
  kubernetes {
    config_path = "~/.kube/config"
    config_context  = var.k8s_context
  }
}

# Helm Buildkite Agent Spec
locals {
  buildkite_config_envs = [
    # Buildkite EnvVars
    {
      # inject Google Cloud application credentials into agent runtime for enabling buildkite artifact uploads
      "name" = "BUILDKITE_GS_APPLICATION_CREDENTIALS_JSON"
      "value" = var.enable_gcs_access ? base64decode(google_service_account_key.buildkite_svc_key[0].private_key) : var.google_app_credentials
    },
    {
      "name" = "BUILDKITE_ARTIFACT_UPLOAD_DESTINATION"
      "value" = var.artifact_upload_path
    },
    {
      "name" = "BUILDKITE_API_TOKEN"
      "value" = data.aws_secretsmanager_secret_version.buildkite_api_token.secret_string
    },
    # Summon EnvVars
    {
      "name" = "SUMMON_DOWNLOAD_URL"
      "value" = var.summon_download_url
    },
    {
      "name" = "SECRETSMANAGER_DOWNLOAD_URL"
      "value" = var.secretsmanager_download_url
    },
    # Google Cloud EnvVars
    {
      # used by GSUTIL tool for accessing GCS data
      "name" = "CLUSTER_SERVICE_EMAIL"
      "value" = var.enable_gcs_access? google_service_account.gcp_buildkite_account[0].email : ""
    },
    {
      "name" = "GCLOUDSDK_DOWNLOAD_URL"
      "value" = var.gcloudsdk_download_url
    },
    {
      "name" = "UPLOAD_BIN"
      "value" = var.artifact_upload_bin
    },
    {
      "name" = "CODA_HELM_REPO"
      "value" = var.coda_helm_repo
    },
    # AWS EnvVars
    {
      "name" = "AWS_ACCESS_KEY_ID"
      "value" = aws_iam_access_key.buildkite_aws_key.id
    },
    {
      "name" = "AWS_SECRET_ACCESS_KEY"
      "value" = aws_iam_access_key.buildkite_aws_key.secret
    },
    {
      "name" = "AWS_REGION"
      "value" = "us-west-2"
    },
    # Docker EnvVars
    {
      "name" = "DOCKER_PASSWORD"
      "value" = data.aws_secretsmanager_secret_version.buildkite_docker_token.secret_string
    }
  ]
}

locals {
  default_agent_vars = {
    image = {
      tag        = var.agent_version
      pullPolicy = var.image_pullPolicy
    }

    privateSshKey = var.agent_vcs_privkey

    # Using Buildkite's config-setting <=> env-var mapping, convert all k,v's stored within agent config as extra environment variables
    # in order to specify custom configuration (see: https://buildkite.com/docs/agent/v3/configuration#configuration-settings)
    extraEnv = concat(local.buildkite_config_envs,
    [for key, value in var.agent_config : { "name" : "BUILDKITE_$(upper(key))", "value" : value }])

    dind = {
      enabled = var.dind_enabled
    }

    podAnnotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/path" = "/metrics"
    }

    rbac = {
      create = true
      role = {
        rules = [
          {
            apiGroups = [
              "",
              "apps",
              "batch"
            ],
            resources = [
              "*"
            ],
            verbs = [
              "get",
              "list",
              "watch"
            ]
          }
        ]
      }
    }

    entrypointd = {
      "01-install-gcloudsdk" = <<-EOF
        #!/bin/bash

        set -eou pipefail
        set +x

        if [[ ! -f $${UPLOAD_BIN} ]]; then
          echo "Downloading gcloud sdk because it doesn't exist"
          apt-get -y update && apt install -y wget python && wget $${GCLOUDSDK_DOWNLOAD_URL}

          tar -zxf $(basename $${GCLOUDSDK_DOWNLOAD_URL}) -C /usr/local/

          # create local user bin symlinks for easier PATH access
          ln --symbolic --force /usr/local/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil
          ln --symbolic --force /usr/local/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud
          ln --symbolic --force /usr/local/google-cloud-sdk/bin/docker-credential-gcloud /usr/local/bin/docker-credential-gcloud

          echo "$${BUILDKITE_GS_APPLICATION_CREDENTIALS_JSON}" > /tmp/gcp_creds.json

          export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcp_creds.json && /usr/local/google-cloud-sdk/bin/gcloud auth activate-service-account $${CLUSTER_SERVICE_EMAIL} --key-file /tmp/gcp_creds.json

          # enable GCR write access
          gcloud components install --quiet docker-credential-gcr
          gcloud auth configure-docker --quiet gcr.io
        fi
      EOF

      "01-install-summon" = <<-EOF
        #!/bin/bash

        set -eou pipefail
        set +x

        export SUMMON_BIN=/usr/local/bin/summon
        export SECRETSMANAGER_LIB=/usr/local/lib/summon/summon-aws-secrets

        # download and install summon binary executable
        if [[ ! -f $${SUMMON_BIN} ]]; then
          echo "Downloading summon because it doesn't exist"
          apt-get -y update && apt install -y wget && wget $${SUMMON_DOWNLOAD_URL}

          tar -xzf $(basename $${SUMMON_DOWNLOAD_URL}) -C /usr/local/bin/
        fi

        # download and install summon AWS Secrets provider
        if [[ ! -f $${SECRETSMANAGER_LIB} ]]; then
          echo "Downloading summon AWS secrets manager because it doesn't exist"
          wget $${SECRETSMANAGER_DOWNLOAD_URL}

          mkdir -p $(dirname $${SECRETSMANAGER_LIB})
          tar -xzf $(basename $${SECRETSMANAGER_DOWNLOAD_URL}) -C $(dirname $${SECRETSMANAGER_LIB})
        fi
      EOF

      "02-install-k8s-tools" = <<-EOF
        #!/bin/bash

        set -eou pipefail
        set +x

        export CI_SHARED_BIN="/var/buildkite/shared/bin"
        mkdir -p "$${CI_SHARED_BIN}"

        # Install kubectl
        apt-get update --yes && apt-get install --yes lsb-core apt-transport-https curl jq

        export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
        echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
        apt-get update -y && apt-get install kubectl -y
        cp --update --verbose $(which kubectl) "$${CI_SHARED_BIN}/kubectl"

        # Install helm
        curl https://baltocdn.com/helm/signing.asc | apt-key add -
        echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
        apt-get update -y && apt-get install helm -y --allow-unauthenticated
        cp --update --verbose $(which helm) "$${CI_SHARED_BIN}/helm"
      EOF
    }
  }
}

resource "kubernetes_namespace" "cluster_namespace" {
  provider = kubernetes.bk_deploy

  metadata {
    name = var.cluster_name
  }
}

resource "helm_release" "buildkite_agents" {
  for_each   = var.agent_topology

  provider   = helm.bk_deploy
 
  name              = "${var.cluster_name}-buildkite-${each.key}"
  repository        = "buildkite"
  chart             = var.helm_chart
  namespace         = var.cluster_namespace
  create_namespace  = true
  version           = var.chart_version

  values = [
    yamlencode(merge(local.default_agent_vars, each.value))
  ]

  wait = false
}
