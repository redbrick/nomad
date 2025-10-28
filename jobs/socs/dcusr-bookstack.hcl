job "dcusr-bookstack" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "wiki.solarracing.ie"
  }

  group "bookstack" {
    count = 1

    network {
      port "http" {
        to = 80
      }

      port "db" {
        to = 3306
      }

      port "redis" {
        to = 6379
      }
    }

    service {
      name = "bookstack"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dcusr-bookstack.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.dcusr-bookstack.entrypoints=web,websecure",
        "traefik.http.routers.dcusr-bookstack.tls.certresolver=lets-encrypt",
      ]
    }

    task "bookstack" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/bookstack:latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/config",
        ]
      }

      template {
        destination = "local.env"
        env         = true
        data        = <<EOH
PUID = "1000"
PGID = "1000"
TZ   = "Europe/Dublin"

APP_URL=https://{{ env "NOMAD_META_domain" }}
APP_KEY={{ key "socs/dcusr/bookstack/app/key" }}
APP_AUTO_LANG_PUBLIC=false

DB_HOST={{ env "NOMAD_HOST_IP_db" }}
DB_PORT={{ env "NOMAD_HOST_PORT_db" }}
DB_USERNAME={{ key "socs/dcusr/bookstack/db/user" }}
DB_PASSWORD={{ key "socs/dcusr/bookstack/db/password" }}
DB_DATABASE={{ key "socs/dcusr/bookstack/db/name" }}

MAIL_DRIVER=smtp
MAIL_HOST={{ key "socs/dcusr/bookstack/smtp/host" }}
MAIL_PORT=587
MAIL_ENCRYPTION=tls
MAIL_USERNAME={{ key "socs/dcusr/bookstack/smtp/user" }}
MAIL_PASSWORD={{ key "socs/dcusr/bookstack/smtp/password" }}
MAIL_FROM={{ key "socs/dcusr/bookstack/smtp/user" }}
MAIL_FROM_NAME={{ key "socs/dcusr/bookstack/smtp/name" }}

REDIS_SERVERS={{ env "NOMAD_ADDR_redis" }}

QUEUE_CONNECTION=redis
CACHE_DRIVER=redis
SESSION_DRIVER=redis
EOH
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }

    task "mariadb" {
      driver = "docker"

      config {
        image = "mariadb:10.11"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/mysql",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
MYSQL_ROOT_PASSWORD={{ key "socs/dcusr/bookstack/db/root/password" }}
MYSQL_DATABASE={{ key "socs/dcusr/bookstack/db/name" }}
MYSQL_USER={{ key "socs/dcusr/bookstack/db/user" }}
MYSQL_PASSWORD={{ key "socs/dcusr/bookstack/db/password" }}
EOH
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:7-alpine"
        ports = ["redis"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/data",
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    task "queue-worker" {
      driver = "docker"

      config {
        image   = "lscr.io/linuxserver/bookstack:latest"
        command = "php"
        args    = ["/app/www/artisan", "queue:work", "--sleep=3", "--tries=3", "--timeout=60"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/config",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
PUID = "1000"
PGID = "1000"
TZ   = "Europe/Dublin"

APP_URL=https://{{ env "NOMAD_META_domain" }}
APP_KEY={{ key "socs/dcusr/bookstack/app/key" }}

DB_HOST={{ env "NOMAD_HOST_IP_db" }}
DB_PORT={{ env "NOMAD_HOST_PORT_db" }}
DB_USERNAME={{ key "socs/dcusr/bookstack/db/user" }}
DB_PASSWORD={{ key "socs/dcusr/bookstack/db/password" }}
DB_DATABASE={{ key "socs/dcusr/bookstack/db/name" }}

MAIL_DRIVER=smtp
MAIL_HOST={{ key "socs/dcusr/bookstack/smtp/host" }}
MAIL_PORT=587
MAIL_ENCRYPTION=tls
MAIL_USERNAME={{ key "socs/dcusr/bookstack/smtp/user" }}
MAIL_PASSWORD={{ key "socs/dcusr/bookstack/smtp/password" }}
MAIL_FROM={{ key "socs/dcusr/bookstack/smtp/user" }}
MAIL_FROM_NAME={{ key "socs/dcusr/bookstack/smtp/name" }}

REDIS_SERVERS={{ env "NOMAD_ADDR_redis" }}

QUEUE_CONNECTION=redis
EOH
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }
}
