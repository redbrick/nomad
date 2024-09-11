job "dcusr-outline" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "outline.solarracing.ie"
  }

  group "outline" {
    network {
      # mode = "bridge"
      port "http" {
        static = 3000
        to     = 3000
      }

      port "db" {
        to = 5432
      }

      port "redis" {
        to = 6379
      }
    }

    service {
      name = "outline"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.dcusr-outline.entrypoints=web,websecure",
        "traefik.http.routers.dcusr-outline.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.dcusr-outline.tls=true",
        "traefik.http.routers.dcusr-outline.tls.certresolver=lets-encrypt",
      ]
    }

    task "app" {
      driver = "docker"

      config {
        image = "docker.getoutline.com/outlinewiki/outline:latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/outline/data:/var/lib/outline/data"
        ]
      }

      resources {
        cpu    = 1000
        memory = 500
      }

      template {
        data        = <<EOH
NODE_ENV=production

SECRET_KEY={{ key "outline/secret/key" }}
UTILS_SECRET={{ key "outline/secret/utils" }}

DATABASE_URL=postgres://{{ key "outline/db/username" }}:{{ key "outline/db/password" }}@{{ env "NOMAD_ADDR_db" }}/{{ key "outline/db/name" }}
DATABASE_CONNECTION_POOL_MIN=
DATABASE_CONNECTION_POOL_MAX=
# Uncomment this to disable SSL for connecting to Postgres
PGSSLMODE=disable

REDIS_URL=redis://{{ env "NOMAD_ADDR_redis" }}

URL=https://{{ env "NOMAD_META_domain" }}
PORT=3000
COLLABORATION_URL=https://{{ env "NOMAD_META_domain" }}

FILE_STORAGE=local
FILE_STORAGE_LOCAL_ROOT_DIR=/var/lib/outline/data

# Maximum allowed size for the uploaded attachment.
FILE_STORAGE_UPLOAD_MAX_SIZE=262144000

GOOGLE_CLIENT_ID     = "{{ key "outline/google/client/id" }}"
GOOGLE_CLIENT_SECRET = "{{ key "outline/google/client/secret" }}"

FORCE_HTTPS = false

ENABLE_UPDATES = true

WEB_CONCURRENCY = 1

DEBUG = http

# error, warn, info, http, verbose, debug and silly
LOG_LEVEL=info

SMTP_HOST       = "{{ key "outline/smtp/host" }}"
SMTP_PORT       = "{{ key "outline/smtp/port" }}"
SMTP_USERNAME   = "{{ key "outline/smtp/username" }}"
SMTP_PASSWORD   = "{{ key "outline/smtp/password" }}"
SMTP_FROM_EMAIL = "{{ key "outline/smtp/from" }}"

DEFAULT_LANGUAGE=en_US
EOH
        destination = "local/.env"
        env         = true
      }
    }

    task "outline-redis" {
      driver = "docker"

      config {
        image = "redis:latest"
        ports = ["redis"]
      }
    }

    task "outline-db" {
      driver = "docker"

      config {
        image = "postgres:alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/outline/postgres:/var/lib/postgresql/data"
        ]
      }

      template {
        data        = <<EOH
POSTGRES_DB       = "{{ key "outline/db/name" }}"
POSTGRES_USER     = "{{ key "outline/db/username" }}"
POSTGRES_PASSWORD = "{{ key "outline/db/password" }}"
EOH
        destination = "local/db.env"
        env         = true
      }
    }
  }
}
