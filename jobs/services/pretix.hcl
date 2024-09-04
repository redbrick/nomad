job "pretix" {
  datacenters = ["aperture"]

  type = "service"

  group "web" {
    network {
    # mode = "bridge"
      port "http" {
        to = 80
      }

      port "db" {
        to = 5432
        static = 5432
      }

      port "redis" {
        to = 6379
      }
    }

    service {
      name = "pretix"
      port = "http"

      # check {
      #   type     = "http"
      #   path     = "/"
      #   interval = "10s"
      #   timeout  = "2s"
      # }

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.pretix.rule=Host(`tickets.solarracing.ie`)",
        "traefik.http.routers.pretix.tls=true",
        "traefik.http.routers.pretix.tls.certresolver=lets-encrypt",
      ]
    }

    task "app" {
      driver = "docker"

      config {
        image = "pretix/standalone:stable"
        ports = ["http"]

        volumes = [
          "local/pretix.cfg:/etc/pretix/pretix.cfg",
          "/storage/nomad/pretix/data:/data"
        ]

      }

      resources {
          memory = 15000
        }

      template {
        data        = <<EOH
[pretix]
instance_name=DCU Solar Racing
url=https://tickets.solarracing.ie
currency=EUR
; DO NOT change the following value, it has to be set to the location of the
; directory *inside* the docker container
datadir=/data
registration=on

[locale]
timezone=Europe/Dublin

[database]
backend=postgresql
name={{ key "pretix/db/name" }}
user={{ key "pretix/db/user" }}
password={{ key "pretix/db/password" }}
host={{ env "NOMAD_IP_db" }}
port={{ env "NOMAD_PORT_db" }}

[mail]
from={{ key "pretix/mail/from" }}
host={{ key "pretix/mail/host" }}
user={{ key "pretix/mail/user" }}
password={{ key "pretix/mail/password" }}
port=465
tls=on
ssl=off

[redis]
location=redis://{{ env "NOMAD_ADDR_redis" }}/0
; Remove the following line if you are unsure about your redis'security
; to reduce impact if redis gets compromised.
sessions=true

[celery]
backend=redis://{{ env "NOMAD_ADDR_redis" }}/1
broker=redis://{{ env "NOMAD_ADDR_redis" }}/2
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
          "local/pg_hba.conf:/pg_hba.conf",
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

      template {
        data = <<EOH
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             172.17.0.1/32           trust
host    all             all             ::1/128                 trust
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust
host 	all 		    all 		    all 			        scram-sha-256
EOH

        destination = "local/pg_hba.conf"
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
