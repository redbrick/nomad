job "dcusr-pretix" {
  datacenters = ["aperture"]

  type = "service"

  meta {
    domain = "tickets.solarracing.ie"
  }

  group "web" {
    network {
      # mode = "bridge"
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

    service {
      name = "pretix-web"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.pretix.entrypoints=web,websecure",
        "traefik.http.routers.pretix.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.pretix.tls=true",
        "traefik.http.routers.pretix.tls.certresolver=lets-encrypt",
      ]
    }

    task "pretix" {
      driver = "docker"

      config {
        image = "pretix/standalone:stable"
        ports = ["http"]

        volumes = [
          "local/pretix.cfg:/etc/pretix/pretix.cfg",
          "/storage/nomad/pretix/data:/data",
          "/etc/timezone:/etc/timezone:ro",
        ]

      }

      resources {
        memory = 5000
        cores  = 1
      }
      env {
        NUM_WORKERS = 1
      }

      template {
        data        = <<EOH
[pretix]
instance_name=DCU Solar Racing
url=https://{{ env "NOMAD_META_domain" }}
currency=EUR
datadir=/data
registration=off

[locale]
timezone=Europe/Dublin

[database]
backend=postgresql
name={{ key "pretix/db/name" }}
user={{ key "pretix/db/user" }}
password={{ key "pretix/db/password" }}
host={{ env "NOMAD_IP_db" }}
port={{ env "NOMAD_HOST_PORT_db" }}

[mail]
from={{ key "pretix/mail/from" }}
host={{ key "pretix/mail/host" }}
user={{ key "pretix/mail/user" }}
password={{ key "pretix/mail/password" }}
port=587
tls=on
ssl=off

[redis]
location=redis://{{ env "NOMAD_ADDR_redis" }}/0
sessions=true

[celery]
backend=redis://{{ env "NOMAD_ADDR_redis" }}/1
broker=redis://{{ env "NOMAD_ADDR_redis" }}/2
worker_prefetch_multiplier = 0
EOH
        destination = "local/pretix.cfg"
      }
    }


    task "pretix-db" {
      driver = "docker"

      config {
        image = "postgres:16-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/pretix/db:/var/lib/postgresql/data",
        ]
      }

      template {
        data        = <<EOH
POSTGRES_USER={{ key "pretix/db/user" }}
POSTGRES_PASSWORD={{ key "pretix/db/password" }}
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
    }
  }
}
