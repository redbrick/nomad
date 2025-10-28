job "dcusr-hi-events" {
  datacenters = ["aperture"]

  type = "service"

  meta {
    domain = "tickets.solarracing.ie"
  }

  group "web" {
    network {
      port "http" {
        to = 80
      }

      port "db" {
        to = 5432
      }

      port "redis" {
        to = 6379
      }
    }

    task "frontend" {
      driver = "docker"

      config {
        image = "daveearley/hi.events-all-in-one"
        ports = ["http"]
      }

      service {
        name = "frontend"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.port=${NOMAD_PORT_http}",
          "traefik.http.routers.hievents-frontend.entrypoints=web,websecure",
          "traefik.http.routers.hievents-frontend.rule=Host(`${NOMAD_META_domain}`)",
          "traefik.http.routers.hievents-frontend.tls=true",
          "traefik.http.routers.hievents-frontend.tls.certresolver=lets-encrypt",
        ]
      }

      resources {
        memory = 3000
        cores  = 1
      }

      template {
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
DB_HOST={{ env "NOMAD_IP_db" }}
DB_PORT={{ env "NOMAD_HOST_PORT_db" }}
DB_DATABASE={{ key "hi-events/db/name" }}
DB_USERNAME={{ key "hi-events/db/user" }}
DB_PASSWORD={{ key "hi-events/db/password" }}

# Redis
REDIS_HOST={{ env "NOMAD_IP_redis" }}
REDIS_USER={{ key "hi-events/redis/user" }}
REDIS_PASSWORD=
REDIS_PORT={{ env "NOMAD_HOST_PORT_redis" }}
EOH
        destination = "local/.env"
        env         = true
      }
    }

    task "db" {
      driver = "docker"

      config {
        image = "postgres:16-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/hi-events-all-in-one/db:/var/lib/postgresql/data",
        ]
      }

      template {
        data        = <<EOH
POSTGRES_DB={{ key "hi-events/db/name" }}
POSTGRES_USER={{ key "hi-events/db/user" }}
POSTGRES_PASSWORD={{ key "hi-events/db/password" }}
EOH
        destination = "local/db.env"
        env         = true
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:latest"
        ports = ["redis"]
      }

      template {
        data        = <<EOH
REDIS_USER={{ key "hi-events/redis/user" }}
EOH
        destination = "local/redis.env"
        env         = true
      }
    }
  }
}
