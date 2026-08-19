job "openldap-quota-sync" {
  datacenters = ["aperture"]
  type        = "batch"

  periodic {
    crons            = ["0 0 * * * *"]
    prohibit_overlap = true
    time_zone        = "Europe/Dublin"
  }

  group "quotasync" {
  count = 1

    service {
      name     = "openldap-quota-sync"
      provider = "consul"
    }

    task "ldap-quota-sync" {
      driver = "docker"

      config {
        image        = "python:3.12-alpine"
        network_mode = "host"

        volumes = [
          "/storage/nomad/openldap/quotasync:/quotas",
        ]

        entrypoint = ["/bin/sh", "-lc"]

        args = [<<EOS
set -eu

python -m pip install --no-cache-dir websocket-client ldap3

exec python "${NOMAD_TASK_DIR}/truenas-quota-sync.py"
EOS
        ]

      }

      template {
        destination = "local/truenas-quota-sync.py"
        perms       = "0755"
        change_mode = "restart"

        data = file("scripts/truenas-quota-sync.py")
      }

      # Fetch the password from Consul KV via a Nomad template.
      template {
          destination = "secrets/ldap-env"
          env         = true
          change_mode = "restart"

          data = <<EOF
LDAP_USERNAME={{ key "ldap/quotasearch/username" }}
LDAP_PASSWORD={{ key "ldap/quotasearch/password" }}
TRUENAS_API_KEY={{ key "ldap/quotasearch/truenas/apikey" }}
TRUENAS_URL={{ key "ldap/quotasearch/truenas/url" }}
EOF
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }
}