job "dcusr-dev" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "solarracing.ie"
  }

  group "web" {
    count = 1

    network {
      port "http" {
        to = 3000
      }
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }


    service {
      name = "dcusr"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "2s"
      }


      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dcusr-dev.rule=Host(`solarracing.ie`) || Host(`www.solarracing.ie`)",
        "traefik.http.routers.dcusr-dev.entrypoints=web,websecure",
        "traefik.http.routers.dcusr-dev.tls.certresolver=lets-encrypt",
        "traefik.http.routers.dcusr-dev.middlewares=dcusr-nextauth-headers",
        "traefik.http.middlewares.dcusr-nextauth-headers.headers.sslProxyHeaders.X-Forwarded-Proto=https",
        "traefik.http.middlewares.dcusr-nextauth-headers.headers.customRequestHeaders.X-Forwarded-Host=solarracing.ie",

      ]
    }

    task "nextjs-website" {
      driver = "docker"

      config {
        image      = "ghcr.io/dcu-solar-racing/website:main"
        ports      = ["http"]
        force_pull = true

        auth {
          username = "${DOCKER_USER}"
          password = "${DOCKER_PASS}"
        }
      }
      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
DOCKER_USER={{ key "dcusr/ghcr/username" }}
DOCKER_PASS={{ key "dcusr/ghcr/password" }}

NEXT_PUBLIC_SITE_URL=https://{{ env "NOMAD_META_domain" }}

AUTH_URL=https://{{ env "NOMAD_META_domain" }}
AUTH_TRUST_HOST=true
AUTH_SECRET={{ key "socs/dcusr-dev/auth/secret" }}

NEXTAUTH_URL=https://{{ env "NOMAD_META_domain" }}
NEXTAUTH_SECRET={{ key "socs/dcusr-dev/auth/secret" }}

PREVIEW_SECRET={{ key "socs/dcusr-dev/preview/secret" }}

SEED_ADMIN_EMAIL={{ key "socs/dcusr-dev/seed/email" }}
SEED_ADMIN_PASSWORD={{ key "socs/dcusr-dev/seed/password" }}

DATABASE_URL=postgresql://{{ key "socs/dcusr-dev/db/user" | urlquery }}:{{ key "socs/dcusr-dev/db/password" | urlquery }}@{{ range service "dcusr-dev-db" }}{{ .Address }}:{{ .Port }}{{ end }}/{{ key "socs/dcusr-dev/db/name" | urlquery }}?schema=public

MINIO_ENDPOINT={{ key "socs/dcusr-dev/minio/url" }}
MINIO_PORT={{ key "socs/dcusr-dev/minio/port" }}
MINIO_ACCESS_KEY="{{ key "socs/dcusr-dev/minio/access/key" }}"
MINIO_SECRET_KEY="{{ key "socs/dcusr-dev/minio/secret/key" }}"
MINIO_BUCKET={{ key "socs/dcusr-dev/minio/bucket" }}
MINIO_USE_SSL=true
MINIO_PUBLIC_BASE_URL={{ key "socs/dcusr-dev/minio/base/url" }}
MINIO_FORCE_PATH_STYLE=true
MINIO_PUBLIC_URL={{ key "socs/dcusr-dev/minio/public/url" }}
MINIO_REGION=ie-redbrick

SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_USER={{ key "socs/dcusr-dev/smtp/user" }}
SMTP_PASS={{ key "socs/dcusr-dev/smtp/password" }}
MAIL_FROM={{ key "socs/dcusr-dev/mail/from" }}
MAIL_TO={{ key "socs/dcusr-dev/mail/to" }}
SMTP_SECURE=true
SMTP_REJECT=true

MAIL_BRAND="DCU Solar Racing"
MAIL_PRIMARY="#22c55e"

PLAUSIBLE_BASE_URL={{ key "socs/dcusr-dev/plausible/url" }}

NEXT_PUBLIC_RECAPTCHA_SITE_KEY={{ key "socs/dcusr/captcha/site/key"}}
RECAPTCHA_SECRET={{ key "socs/dcusr/captcha/secret/key" }}
EOH
      }
    }

    task "wait-for-db" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "postgres:17-alpine"
        command = "sh"
        args = [
          "-c",
          "while ! pg_isready -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER}; do echo 'Waiting for DB...'; sleep 1; done; echo 'DB is ready!'"
        ]
      }

      template {
        destination = "local/wait.env"
        env         = true
        data        = <<EOH
{{ range service "dcusr-dev-db" }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{ end }}
DB_USER={{ key "socs/dcusr-dev/db/user" }}
EOH
      }

      resources {
        memory = 128
      }
    }
  }

  group "database" {
    count = 1

    network {
      port "db" {
        to = 5432
      }
    }

    update {
      max_parallel = 0 # don't update this group automatically
      auto_revert  = false
    }

    task "db" {
      driver         = "docker"
      kill_signal    = "SIGTERM" # SIGTERM instead of SIGKILL so database can shutdown safely
      kill_timeout   = "30s"
      shutdown_delay = "5s"

      service {
        name = "dcusr-dev-db"
        port = "db"

        check {
          type     = "script"
          name     = "postgres-ready"
          command  = "/bin/sh"
          args     = ["-c", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
          interval = "10s"
          timeout  = "2s"
        }
      }


      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/postgresql/data",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
POSTGRES_DB={{ key "socs/dcusr-dev/db/name" }}
POSTGRES_USER={{ key "socs/dcusr-dev/db/user" }}
POSTGRES_PASSWORD={{ key "socs/dcusr-dev/db/password" }}
EOH
      }
    }
  }
}
