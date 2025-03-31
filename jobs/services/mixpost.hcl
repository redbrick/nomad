job "mixpost" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "mixpost.redbrick.dcu.ie"
  }

  group "mixpost" {
    network {
      port "http" {
        to = 80
      }

      port "redis" {
        to = 6379
      }

      port "db" {
        to = 3306
      }
    }

    service {
      name = "mixpost"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.mixpost.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.mixpost.entrypoints=web,websecure",
        "traefik.http.routers.mixpost.tls.certresolver=lets-encrypt",
        "traefik.http.middlewares.mixpost.headers.SSLRedirect=true",
      ]
    }


    task "mixpost" {
      driver = "docker"

      config {
        image = "inovector/mixpost-pro-team:latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}/app:/var/www/html/storage/app"
        ]
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      template {
        data        = <<EOH
LICENSE_KEY={{ key "mixpost/license/key" }}

APP_NAME=MIXPOST

APP_KEY={{ key "mixpost/app/key" }}
APP_DEBUG=true
APP_DOMAIN={{ env "NOMAD_META_domain" }}
APP_URL=https://{{ env "NOMAD_META_domain" }}

DB_HOST={{ env "NOMAD_IP_db" }}
DB_PORT={{ env "NOMAD_HOST_PORT_db" }}
DB_DATABASE={{ key "mixpost/db/name" }}
DB_USERNAME={{ key "mixpost/db/user" }}
DB_PASSWORD={{ key "mixpost/db/password" }}

REDIS_HOST={{ env "NOMAD_IP_redis" }}
REDIS_PORT={{ env "NOMAD_HOST_PORT_redis" }}

# MAIL_HOST=
# MAIL_PORT=
# MAIL_USERNAME=
# MAIL_PASSWORD=
# MAIL_ENCRYPTION=tls
# MAIL_FROM_ADDRESS=no-reply@redbrick.dcu.ie
# MAIL_FROM_NAME=${APP_NAME}
# SSL_EMAIL

# POSSIBLE INTEGRATION WITH MINIO MORE RESEARCH NECESSARY
# MIXPOST_DISK=s3
EOH
        destination = "local/.env"
        env         = true
      }
    }

    task "mixpost-redis" {
      driver = "docker"

      config {
        image = "redis:latest"
        ports = ["redis"]
      }

      lifecycle {
        hook    = "prestart"
        sidecar = "true"
      }
    }

    task "mariadb" {
      driver = "docker"

      template {
        data = <<EOH
MYSQL_DATABASE={{ key "mixpost/db/name" }}
MYSQL_USER={{ key "mixpost/db/user" }}
MYSQL_PASSWORD={{ key "mixpost/db/password" }}
MYSQL_RANDOM_ROOT_PASSWORD=yes
EOH

        destination = "local/file.env"
        env         = true
      }

      config {
        image = "mariadb:latest"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}/mysql:/var/lib/mysql",
          "local/server.cnf:/etc/mysql/mariadb.conf.d/50-server.cnf",
        ]
      }

      template {
        data        = <<EOH
[mariadbd]

pid-file                = /run/mysqld/mysqld.pid
basedir                 = /usr

bind-address            = 0.0.0.0

expire_logs_days        = 10

character-set-server     = utf8mb4
character-set-collations = utf8mb4=uca1400_ai_ci
        EOH
        destination = "local/server.cnf"
      }

      resources {
        cpu    = 400
        memory = 800
      }
    }
  }
}
