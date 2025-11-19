job "paperless" {
  datacenters = ["aperture"]
  type        = "service"

  group "paperless-web" {
    network {
      port "http" {
        to = 8000
      }
      port "redis" {
        to = 6379
      }
      port "db" {
        to = 5432
      }
    }

    service {
      name = "paperless"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.paperless.rule=Host(`paperless.redbrick.dcu.ie`) || Host(`paperless.rb.dcu.ie`)",
        "traefik.http.routers.paperless.entrypoints=websecure",
        "traefik.http.routers.paperless.tls=true",
        "traefik.http.routers.paperless.tls.certresolver=rb",
        "traefik.http.middlewares.paperless.headers.contentSecurityPolicy=default-src 'self'; img-src 'self' data:"
      ]
    }

    task "web" {
      driver = "docker"

      config {
        image = "ghcr.io/paperless-ngx/paperless-ngx:latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/paperless/consume:/usr/src/paperless/consume",
          "/storage/nomad/paperless/data:/usr/src/paperless/data",
          "/storage/nomad/paperless/media:/usr/src/paperless/media",
          "/storage/nomad/paperless/export:/usr/src/paperless/export",
          "/storage/nomad/paperless/preconsume:/usr/src/paperless/preconsume",
        ]
      }

      template {
        data        = <<EOH
PAPERLESS_REDIS  = "redis://{{ env "NOMAD_ADDR_redis" }}"
PAPERLESS_DBHOST = "{{ env "NOMAD_IP_db" }}"
PAPERLESS_DBPORT = "{{ env "NOMAD_HOST_PORT_db" }}"
PAPERLESS_DBPASS={{ key "paperless/db/password" }}
PAPERLESS_DBUSER={{ key "paperless/db/user" }}
PAPERLESS_DBNAME={{ key "paperless/db/name" }}
PAPERLESS_SECRETKEY={{ key "paperless/secret_key" }}
PAPERLESS_URL=https://paperless.redbrick.dcu.ie
PAPERLESS_ADMIN_USER={{ key "paperless/admin/user" }}
PAPERLESS_ADMIN_PASSWORD={{ key "paperless/admin/password" }}
PAPERLESS_ALLOWED_HOSTS="paperless.redbrick.dcu.ie,paperless.rb.dcu.ie,10.10.0.4,10.10.0.5,10.10.0.6" # allow internal aperture IPs for health check
PAPERLESS_CONSUMER_POLLING=1
EOH
        destination = "local/.env"
        env         = true
      }
      # PAPERLESS_PRE_CONSUME_SCRIPT={{ key "paperless/env/preconsume-script" }}

      resources {
        cpu    = 800
        memory = 1000
      }
    }

    task "broker" {
      driver = "docker"

      config {
        image = "docker.io/library/redis:7"
        ports = ["redis"]
      }

      resources {
        cpu    = 300
        memory = 50
      }
    }

    task "db" {
      driver = "docker"

      config {
        image = "postgres:16-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/paperless/db:/var/lib/postgresql/data"
        ]
      }

      template {
        data        = <<EOH
POSTGRES_PASSWORD={{ key "paperless/db/password" }}
POSTGRES_USER={{ key "paperless/db/user" }}
POSTGRES_NAME={{ key "paperless/db/name" }}
EOH
        destination = "local/db.env"
        env         = true
      }
    }
  }
}
