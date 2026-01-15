job "shlink" {
  datacenters = ["aperture"]

  type = "service"

  group "web" {
    network {
      port "api" {
      }
      port "web" {
        to = 8080
      }
      port "db" {
        to = 5432
      }
    }

    task "api" {
      driver = "docker"

      service {
        name = "shlink-api"
        port = "api"

        check {
          type     = "http"
          path     = "/rest/health"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.shlink-api.entrypoints=web,websecure",
          "traefik.http.routers.shlink-api.rule=Host(`s.rb.dcu.ie`)",
          "traefik.http.routers.shlink-api.tls=true",
          "traefik.http.routers.shlink-api.tls.certresolver=rb",
        ]
      }

      config {
        image = "shlinkio/shlink"
        ports = ["api"]
      }

      template {
        data        = <<EOH
DEFAULT_DOMAIN=s.rb.dcu.ie
IS_HTTPS_ENABLED=true
TIMEZONE=Europe/Dublin
TRUSTED_PROXIES=136.206.16.0/24,10.10.0.0/24,127.0.0.0/8

INITIAL_API_KEY={{ key "shlink/api/key" }}
GEOLITE_LICENSE_KEY={{ key "shlink/geolite/key" }}
SHELL_VERBOSITY=3
PORT={{ env "NOMAD_HOST_PORT_api"}}

DB_DRIVER=postgres
DB_USER={{ key "shlink/db/user" }}
DB_PASSWORD={{ key "shlink/db/password" }}
DB_NAME={{ key "shlink/db/name" }}
DB_HOST={{ env "NOMAD_IP_db" }}
DB_PORT={{ env "NOMAD_HOST_PORT_db" }}

DEFAULT_BASE_URL_REDIRECT=https://redbrick.dcu.ie/
DEFAULT_REGULAR_404_REDIRECT=https://redbrick.dcu.ie/
DEFAULT_INVALID_SHORT_URL_REDIRECT=https://redbrick.dcu.ie/
EOH
        destination = "local/file.env"
        env         = true
      }
      resources {
        memory = 2048
      }
    }

    task "web" {
      driver = "docker"

      service {
        name = "shlink-web"
        port = "web"

        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.shlink-web.entrypoints=web,websecure",
          "traefik.http.routers.shlink-web.rule=Host(`shlink.redbrick.dcu.ie`)",
          "traefik.http.routers.shlink-web.tls=true",
          "traefik.http.routers.shlink-web.tls.certresolver=rb",
        ]
      }

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image = "shlinkio/shlink-web-client"
        ports = ["web"]
      }

      template {
        data        = <<EOH
SHLINK_SERVER_URL=https://s.rb.dcu.ie
SHLINK_API_KEY={{ key "shlink/api/key" }}
    EOH
        destination = "local/file.env"
        env         = true
      }

      resources {
        memory = 300
      }
    }

    task "wait-for-db" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "postgres:18-alpine"
        command = "sh"
        args = [
          "-c",
          "while ! pg_isready -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER}; do echo 'Waiting for DB...'; sleep 1; done; echo 'DB is ready!'"
        ]
      }

      template {
        data        = <<EOH
DB_HOST={{ env "NOMAD_IP_db" }}
DB_PORT={{ env "NOMAD_HOST_PORT_db" }}
DB_USER={{ key "shlink/db/user" }}
EOH
        destination = "local/wait.env"
        env         = true
      }

      resources {
        memory = 128
      }
    }

    task "db" {
      driver = "docker"

      service {
        name = "shlink-db"
        port = "db"

        check {
          type     = "script"
          name     = "postgres-ready"
          command  = "/bin/sh"
          args     = ["-c", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_NAME}"]
          interval = "10s"
          timeout  = "2s"
        }
      }

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image = "postgres:18-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/postgresql/",
        ]
      }

      template {
        data        = <<EOH
POSTGRES_PASSWORD={{ key "shlink/db/password" }}
POSTGRES_USER={{ key "shlink/db/user" }}
POSTGRES_NAME={{ key "shlink/db/name" }}
EOH
        destination = "local/db.env"
        env         = true
      }

      resources {
        memory = 1024
      }
    }
  }
}


