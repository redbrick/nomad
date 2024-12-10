job "rally" {
  datacenters = ["aperture"]
  type        = "service"

  group "rally-web" {
    network {
      port "http" {
        to = 3000
      }
      port "db" {
        to = 5432
      }
    }

    service {
      name = "rally"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.rally.rule=Host(`vote.rb.dcu.ie`)",
        "traefik.http.routers.rally.entrypoints=websecure",
        "traefik.http.routers.rally.tls=true",
        "traefik.http.routers.rally.tls.certresolver=lets-encrypt",
      ]
    }

    task "web" {
      driver = "docker"

      config {
        image = "lukevella/rallly:latest"
        ports = ["http"]
      }

      template {
        data        = <<EOH
DATABASE_URL=postgres://{{ key "rally/db/user" }}:{{ key "rally/db/password" }}@{{ env "NOMAD_ADDR_db" }}/{{ key "rally/db/name" }}
PG_PASSWD={{ key "rally/db/password" }}
PG_DB={{ key "rally/db/name" }}

# A random 32-character secret key used to encrypt user sessions
SECRET_PASSWORD={{ key "rally/secret" }}

# The base url where this instance is accessible, including the scheme.
# Example: https://example.com
NEXT_PUBLIC_BASE_URL={{ key "rally/base_url" }}

# NEXTAUTH_URL should be the same as NEXT_PUBLIC_BASE_URL
NEXTAUTH_URL={{ key "rally/base_url" }}

# Toggle Self-Hosted mode
NEXT_PUBLIC_SELF_HOSTED=true

# Comma separated list of email addresses that are allowed to register and login.
# You can use wildcard syntax to match a range of email addresses.
# Example: "john@example.com,jane@example.com" or "*@example.com"
ALLOWED_EMAILS={{ key "rally/email/allowed_emails" }}

# EMAIL CONFIG (required for sending emails)

# The email of whoever is managing this instance in case a user needs support.
SUPPORT_EMAIL={{ key "rally/email/support" }}

# The host address of your SMTP server
SMTP_HOST={{ key "rally/email/host" }}

# The port of your SMTP server
SMTP_PORT={{ key "rally/email/port" }}

# Set to "true" if SSL is enabled for your SMTP connection
SMTP_SECURE=true

# The username (if auth is enabled on your SMTP server)
SMTP_USER={{ key "rally/email/user" }}

# The password (if auth is enabled on your SMTP server)
SMTP_PWD={{ key "rally/email/password" }}
EOH
        destination = "local/.env"
        env         = true
      }

      resources {
        cpu    = 800
        memory = 1000
      }
    }

    task "db" {
      driver = "docker"

      config {
        image = "postgres:17.2-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/rally/db:/var/lib/postgresql/data"
        ]
      }

      template {
        data        = <<EOH
POSTGRES_PASSWORD={{ key "rally/db/password" }}
POSTGRES_USER={{ key "rally/db/user" }}
POSTGRES_NAME={{ key "rally/db/name" }}
EOH
        destination = "local/db.env"
        env         = true
      }
    }
  }
}

