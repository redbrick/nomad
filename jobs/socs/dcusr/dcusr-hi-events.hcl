job "dcusr-hi-events" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "tickets.solarracing.ie"
  }

  group "web" {
    network {
      port "http" {
        to = 80
      }

      port "redis" {
        to = 6379
      }
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    service {
      name = "dcusr-hievents-frontend"
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
        "traefik.http.routers.hievents-frontend.entrypoints=web,websecure",
        "traefik.http.routers.hievents-frontend.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.hievents-frontend.tls=true",
        "traefik.http.routers.hievents-frontend.tls.certresolver=lets-encrypt",
      ]
    }

    task "frontend" {
      driver = "docker"

      config {
        image = "daveearley/hi.events-all-in-one"
        ports = ["http"]
      }

      resources {
        memory = 3000
        cores  = 1
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
# Frontend
VITE_FRONTEND_URL="https://{{ env "NOMAD_META_domain" }}"
VITE_API_URL_CLIENT="https://{{ env "NOMAD_META_domain" }}/api"
VITE_API_URL_SERVER="https://{{ env "NOMAD_META_domain" }}/api"
VITE_STRIPE_PUBLISHABLE_KEY=

# Backend
LOG_CHANNEL=stderr
QUEUE_CONNECTION=redis

# Mail
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_ENCRYPTION=tls
MAIL_PASSWORD={{ key "hi-events/mail/password" }}
MAIL_USERNAME={{ key "hi-events/mail/username" }}
MAIL_FROM_ADDRESS={{ key "hi-events/mail/username" }}
MAIL_FROM_NAME="DCU Solar Racing"

# App configs
APP_KEY={{ key "hi-events/app/key" }}
JWT_SECRET={{key "hi-events/app/jwt" }}
APP_CDN_URL="https://{{ env "NOMAD_META_domain" }}/storage"
APP_FRONTEND_URL="https://{{ env "NOMAD_META_domain" }}"
APP_DISABLE_REGISTRATION=true
APP_SAAS_MODE_ENABLED=ture

# Filesystem
FILESYSTEM_PUBLIC_DISK=public
FILESYSTEM_PRIVATE_DISK=local

# Stripe
STRIPE_PUBLIC_KEY=
STRIPE_SECRET_KEY=

# Database
DB_CONNECTION=pgsql
{{ range service "dcusr-hi-events-db" }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{ end }}
DB_DATABASE={{ key "hi-events/db/name" }}
DB_USERNAME={{ key "hi-events/db/user" }}
DB_PASSWORD={{ key "hi-events/db/password" }}

# Redis
REDIS_HOST={{ env "NOMAD_IP_redis" }}
REDIS_USER={{ key "hi-events/redis/user" }}
REDIS_PASSWORD=
REDIS_PORT={{ env "NOMAD_HOST_PORT_redis" }}
EOH
      }
    }

    task "redis" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image = "redis:latest"
        ports = ["redis"]
      }

      template {
        data        = "REDIS_USER={{ key \"hi-events/redis/user\" }}"
        destination = "local/redis.env"
        env         = true
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
{{- range service "dcusr-listmonk-db" }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{- end }}
DB_USER={{ key "hi-events/db/user" }}
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
        name = "dcusr-hi-events-db"
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
        image = "postgres:16-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/hi-events-all-in-one/db:/var/lib/postgresql/data",
        ]
      }

      template {
        destination = "local/db.env"
        env         = true
        data        = <<EOH
POSTGRES_DB={{ key "hi-events/db/name" }}
POSTGRES_USER={{ key "hi-events/db/user" }}
POSTGRES_PASSWORD={{ key "hi-events/db/password" }}
EOH
      }
    }
  }
}
