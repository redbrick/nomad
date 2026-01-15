job "su-listmonk" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "sulists.redbrick.dcu.ie"
  }

  group "listmonk" {
    network {
      mode = "bridge"
      port "http" {}

      port "db" {
        to = 5432
      }
    }

    service {
      name = "su-listmonk"
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
        "traefik.http.routers.su-listmonk.entrypoints=web,websecure",
        "traefik.http.routers.su-listmonk.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.su-listmonk.tls=true",
        "traefik.http.routers.su-listmonk.tls.certresolver=rb",
      ]
    }

    task "app" {
      driver = "docker"

      config {
        image = "listmonk/listmonk:latest"
        ports = ["http"]

        command = "sh"
        args    = ["-c", "./listmonk --install --idempotent --yes --config '' && ./listmonk --upgrade --yes --config '' && ./listmonk --config ''"] # empty config so envvars are used instead

        volumes = [
          "/storage/nomad/su-listmonk/uploads:/uploads",
        ]
      }

      resources {
        cpu    = 1000
        memory = 500
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
LISTMONK_app__address     = 0.0.0.0:{{ env "NOMAD_PORT_http" }}
LISTMONK_app__public_url  = {{ env "NOMAD_META_domain" }}

LISTMONK_db__user         = {{ key "su/listmonk/db/username" }}
LISTMONK_db__password     = {{ key "su/listmonk/db/password" }}
LISTMONK_db__database     = {{ key "su/listmonk/db/name" }}
LISTMONK_db__host         = {{ env "NOMAD_HOST_IP_db" }}
LISTMONK_db__port         = {{ env "NOMAD_HOST_PORT_db" }}
LISTMONK_db__ssl_mode     = disable
LISTMONK_db__max_open     = 25
LISTMONK_db__max_idle     = 25
LISTMONK_db__max_lifetime = 300s
TZ                        = Etc/UTC
LISTMONK_ADMIN_USER       = {{ key "su/listmonk/admin/username" }}
LISTMONK_ADMIN_PASSWORD   = {{ key "su/listmonk/admin/password" }}
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
DB_HOST={{ env "NOMAD_IP_db" }}
DB_PORT={{ env "NOMAD_HOST_PORT_db" }}
DB_USER={{ key "su/listmonk/db/username" }}
EOH
      }

      resources {
        memory = 128
      }
    }

    task "db" {
      driver = "docker"

      service {
        name = "su-listmonk-db"
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

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/su-listmonk/postgres:/var/lib/postgresql/data"
        ]
      }

      template {
        destination = "local/db.env"
        env         = true
        data        = <<EOH
POSTGRES_DB       = "{{ key "su/listmonk/db/name" }}"
POSTGRES_USER     = "{{ key "su/listmonk/db/username" }}"
POSTGRES_PASSWORD = "{{ key "su/listmonk/db/password" }}"
EOH
      }
    }
  }
}
