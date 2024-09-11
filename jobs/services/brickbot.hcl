job "brickbot2" {
  datacenters = ["aperture"]

  type = "service"

  group "brickbot2" {
    count = 1

    task "brickbot2" {
      driver = "docker"

      config {
        image = "ghcr.io/redbrick/brickbot2:latest"
        auth {
          username = "${DOCKER_USER}"
          password = "${DOCKER_PASS}"
        }
        volumes = [
          "local/ldap.secret:/etc/ldap.secret:ro",
        ]
      }

      template {
        destination = "local/ldap.secret"
        perms       = "600"
        data        = "{{ key \"api/ldap/secret\" }}" # this is necessary as the secret has no EOF
      }

      template {
        destination = "local/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
DOCKER_USER={{ key "brickbot/ghcr/username" }}
DOCKER_PASS={{ key "brickbot/ghcr/password" }}
BOT_DB={{ key "brickbot/db" }}
BOT_TOKEN={{ key "brickbot/discord/token" }}
BOT_PRIVILEGED={{ key "brickbot/discord/privileged" }}
BOT_PREFIX=.
BOT_GUILD={{ key "brickbot/discord/guild" }}
LDAP_HOST={{ key "brickbot/ldap/host" }}
SMTP_DOMAIN={{ key "brickbot/smtp/domain" }}
SMTP_HOST={{ key "brickbot/smtp/host" }}
SMTP_PORT=587
SMTP_USERNAME={{ key "brickbot/smtp/username" }}
SMTP_PASSWORD={{ key "brickbot/smtp/password" }}
SMTP_SENDER={{ key "brickbot/smtp/sender" }}
API_USERNAME={{ key "brickbot/api/username" }}
API_PASSWORD={{ key "brickbot/api/password" }}
VERIFIED_ROLE={{ key "brickbot/discord/verified_role" }}
USER=brickbot
EOH
      }
    }
  }
}
