job "dcusr-listmonk" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "lists.solarracing.ie"
  }

  group "listmonk" {
    network {
      port "http" {
      }

      port "db" {
        to = 5432
      }
    }

    service {
      name = "listmonk"
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
        "traefik.http.routers.dcusr-listmonk.entrypoints=web,websecure",
        "traefik.http.routers.dcusr-listmonk.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.dcusr-listmonk.tls=true",
        "traefik.http.routers.dcusr-listmonk.tls.certresolver=lets-encrypt",
      ]
    }

    task "app" {
      driver = "docker"

      config {
        image = "listmonk/listmonk:latest"
        ports = ["http"]

        entrypoint = ["./listmonk", "--static-dir=/listmonk/static"]

        volumes = [
          "/storage/nomad/dcusr-listmonk/static:/listmonk/static",
          "/storage/nomad/dcusr-listmonk/postgres/:/var/lib/postgresql/data",
          "local/config.toml:/listmonk/config.toml"
        ]
      }

      resources {
        cpu    = 1000
        memory = 500
      }

      template {
        data        = <<EOH
[app]
address = "0.0.0.0:{{ env "NOMAD_PORT_http" }}"

# Database.
[db]
host = "{{ env "NOMAD_HOST_IP_db" }}"
port = {{ env "NOMAD_HOST_PORT_db" }}
user = "{{ key "dcusr/listmonk/db/username" }}"
password = "{{ key "dcusr/listmonk/db/password" }}"
database = "{{ key "dcusr/listmonk/db/name" }}"
ssl_mode = "disable"
max_open = 25
max_idle = 25
max_lifetime = "300s"
EOH
        destination = "local/config.toml"
      }
    }

    task "listmonk-db" {
      driver = "docker"

      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/dcusr-listmonk/postgres:/var/lib/postgresql/data"
        ]
      }

      template {
        data        = <<EOH
POSTGRES_DB       = "{{ key "dcusr/listmonk/db/name" }}"
POSTGRES_USER     = "{{ key "dcusr/listmonk/db/username" }}"
POSTGRES_PASSWORD = "{{ key "dcusr/listmonk/db/password" }}"
EOH
        destination = "local/db.env"
        env         = true
      }
    }
  }
}
