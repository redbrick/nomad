job "vaultwarden" {
  datacenters = ["aperture"]
  type        = "service"

  group "vaultwarden" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "vaultwarden"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.vaultwarden.rule=Host(`vault.redbrick.dcu.ie`)",
        "traefik.http.routers.vaultwarden.entrypoints=websecure",
        "traefik.http.routers.vaultwarden.tls.certresolver=lets-encrypt",
      ]
    }

    task "vaultwarden" {
      driver = "docker"

      config {
        image = "vaultwarden/server:latest-alpine"
        ports = ["http"]

        volumes = [
          "/storage/nomad/vaultwarden:/data"
        ]
      }

      template {
        data = <<EOF
DOMAIN=https://vault.redbrick.dcu.ie
DATABASE_URL=postgresql://{{ key "vaultwarden/db/user" }}:{{ key "vaultwarden/db/password" }}@postgres.service.consul:5432/{{ key "vaultwarden/db/name" }}
SIGNUPS_ALLOWED=false
INVITATIONS_ALLOWED=true

# This is not the actual token, but a hash of it. Vaultwarden does not like the actual token.
ADMIN_TOKEN={{ key "vaultwarden/admin/hash" }}
SMTP_HOST={{ key "vaultwarden/smtp/host" }}
SMTP_FROM={{ key "vaultwarden/smtp/from" }}
SMTP_PORT={{ key "vaultwarden/smtp/port" }}
SMTP_SECURITY=starttls
SMTP_USERNAME={{ key "vaultwarden/smtp/username" }}
SMTP_PASSWORD={{ key "vaultwarden/smtp/password" }}
EOF

        destination = "local/env"
        env         = true
      }
# These yubico variables are not necessary for yubikey support, only to verify the keys with yubico.
#YUBICO_CLIENT_ID={{ key "vaultwarden/yubico/client_id" }}
#YUBICO_SECRET_KEY={{ key "vaultwarden/yubico/secret_key" }}

      resources {
        cpu    = 500
        memory = 500
      }
    }
  }
}
