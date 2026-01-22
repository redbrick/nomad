job "dcusr" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "solarracing.ie"
  }

  group "dcusr" {
    count = 1

    network {
      port "http" {
        to = 3000
      }
      port "db" {
        to = 5432
      }
    }

    service {
      name = "dcusr"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dcusr-dev.rule=Host(`solarracing.ie`) || Host(`www.solarracing.ie`)",
        "traefik.http.routers.dcusr-dev.entrypoints=web,websecure",
        "traefik.http.routers.dcusr-dev.tls.certresolver=lets-encrypt",
        "traefik.http.middlewares.nextauth-headers.headers.sslProxyHeaders.X-Forwarded-Proto=https",
        "traefik.http.middlewares.nextauth-headers.headers.customRequestHeaders.X-Forwarded-Host=solarracing.ie",
        "traefik.http.routers.dcusr-dev.middlewares=nextauth-headers@consulcatalog",

      ]
    }

    task "nextjs-website" {
      driver = "docker"

      config {
        image = "ghcr.io/dcu-solar-racing/website:main"
        ports = ["http"]
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

DATABASE_URL=postgresql://{{ key "socs/dcusr-dev/db/user" | urlquery }}:{{ key "socs/dcusr-dev/db/password" | urlquery }}@{{ env "NOMAD_ADDR_db" }}/{{ key "socs/dcusr-dev/db/name" | urlquery }}?schema=public

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

    task "postgres" {
      driver = "docker"

      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/dcusr-dev/db:/var/lib/postgresql/data",
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
