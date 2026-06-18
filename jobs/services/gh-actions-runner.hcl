job "github-actions-runner" {
  datacenters = ["aperture"]

  type = "service"

  meta {
    version = "2.320.0"
    sha256  = "93ac1b7ce743ee85b5d386f5c1787385ef07b3d7c728ff66ce0d3813d5f46900"
  }

  group "github-actions" {
    count = 3

    spread {
      attribute = "${node.unique.id}"
      weight    = 100
    }

    task "actions-runner" {
      driver = "raw_exec"
      # user   = "nomad"

      config {
        command = "/bin/bash"
        args    = ["${NOMAD_TASK_DIR}/bootstrap.sh"]
      }
      template {
        data        = <<EOF
#!/bin/bash

export RUNNER_ALLOW_RUNASROOT=1
export ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true

echo "Querying API for registration token..."

reg_token=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer {{ key "github/actions-runner/token" }}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/orgs/redbrick/actions/runners/registration-token | jq -r '.token')

echo "Configuring runner..."
bash -c "${NOMAD_TASK_DIR}/config.sh --unattended --url https://github.com/redbrick --token ${reg_token} --name $(hostname) --labels aperture,deployment-runner --replace"

echo "Running actions runner..."
bash "${NOMAD_TASK_DIR}/run.sh"

EOF
        destination = "local/bootstrap.sh"
      }
      artifact {
        source = "https://github.com/actions/runner/releases/download/v2.335.1/actions-runner-linux-x64-2.335.1.tar.gz"
        options {
          checksum = "sha256:4ef2f25285f0ae4477f1fe1e346db76d2f3ebf03824e2ddd1973a2819bf6c8cf"
        }
      }
    }
  }
}
