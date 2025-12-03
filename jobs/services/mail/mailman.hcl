job "mailman" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "lists.redbrick.dcu.ie"
  }

  group "mailman" {
    count = 1

    network {
      port "http" {
        to = 8000
      }
      port "api" {
        to = 8001
      }
      port "lmtp" {
        to = 8024
      }
      port "uwsgi" {
        to = 8080
      }
      port "db" {
        to = 5432
      }
    }

    service {
      name = "mailman"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.mailman.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.mailman.entrypoints=web,websecure",
        "traefik.http.routers.mailman.tls.certresolver=lets-encrypt",
      ]
    }

    service {
      name = "mailman-db"
      port = "db"
    }

    service {
      name = "mailman-lmtp"
      port = "lmtp"
    }

    service {
      name = "mailman-api"
      port = "api"
    }

    task "mailman-web" {
      driver = "docker"

      config {
        image = "maxking/mailman-web:0.5"
        ports = [
          "http",
          "uwsgi",
        ]
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/opt/mailman-web-data:rw",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
DATABASE_TYPE=postgres
HYPERKITTY_API_KEY={{ key "mailman/hyperkitty/api/key" }}
SECRET_KEY={{ key "mailman/web/secret/key" }}

MAILMAN_HOSTNAME={{ env "NOMAD_META_domain" }}
SERVE_FROM_DOMAIN={{ env "NOMAD_META_domain" }}

MAILMAN_ADMIN_USER={{ key "mailman/admin/user" }}
MAILMAN_REST_USER={{ key "mailman/rest/user" }}
MAILMAN_REST_PASSWORD={{ key "mailman/rest/password" }}
MAILMAN_ADMIN_EMAIL={{ key "mailman/admin/email" }}
MAILMAN_REST_URL=http://{{ env "NOMAD_ADDR_api" }}

POSTORIUS_TEMPLATE_BASE_URL=https://{{ env "NOMAD_META_domain" }}
DJANGO_ALLOWED_HOSTS={{ env "NOMAD_META_domain" }}

# Django is stupid, this serves the CSS/static file
UWSGI_STATIC_MAP=/static=/opt/mailman-web-data/static

DATABASE_URL=postgresql://{{ key "mailman/db/user" | urlquery }}:{{ key "mailman/db/password" | urlquery }}@{{ env "NOMAD_HOST_IP_db" }}:{{ env "NOMAD_HOST_PORT_db" }}/{{ key "mailman/db/name" }}

# SMTP
EMAIL_HOST=mail.redbrick.dcu.ie
EMAIL_PORT=587
EMAIL_HOST_USER={{ key "mailman/ldap/user" }}
EMAIL_HOST_PASSWORD={{ key "mailman/ldap/password" }}
EMAIL_USE_TLS=True
SMTP_USE_SSL=False
EOH
      }

      resources {
        cpu    = 500
        memory = 4096
      }
    }

    task "mailman-core" {
      driver = "docker"

      config {
        image = "maxking/mailman-core:0.5"
        ports = [
          "api",
          "lmtp",
        ]
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/opt/mailman:rw",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
DATABASE_TYPE=postgres
DATABASE_CLASS=mailman.database.postgresql.PostgreSQLDatabase
HYPERKITTY_API_KEY={{ key "mailman/hyperkitty/api/key" }}

HYPERKITTY_URL=https://{{ env "NOMAD_META_domain" }}/hyperkitty

MAILMAN_REST_USER={{ key "mailman/rest/user" }}
MAILMAN_REST_PASSWORD={{ key "mailman/rest/password" }}

MM_HOSTNAME=0.0.0.0
MTA=postfix

# DB, it doesnt like it without the urlquery
DATABASE_URL=postgresql://{{ key "mailman/db/user" | urlquery }}:{{ key "mailman/db/password" | urlquery }}@{{ env "NOMAD_HOST_IP_db" }}:{{ env "NOMAD_HOST_PORT_db" }}/{{ key "mailman/db/name" }}

# SMTP
SMTP_HOST=mail.redbrick.dcu.ie
SMTP_PORT=587
SMTP_SECURE_MODE=starttls
SMTP_HOST_USER={{ key "mailman/ldap/user" }}
SMTP_HOST_PASSWORD={{ key "mailman/ldap/password" }}
SMTP_USE_TLS=True
SMTP_USE_SSL=False
EOH
      }

      resources {
        cpu    = 500
        memory = 2048
      }
    }

    task "postgres" {
      driver = "docker"

      config {
        image = "postgres:12-alpine"
        ports = [
          "db",
        ]
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/postgresql/data:rw",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
POSTGRES_DB={{ key "mailman/db/name" }}
POSTGRES_USER={{ key "mailman/db/user" }}
POSTGRES_PASSWORD={{ key "mailman/db/password" }}
EOH
      }

      resources {
        cpu    = 400
        memory = 512
      }
    }
  }
}
