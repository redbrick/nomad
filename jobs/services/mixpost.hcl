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
        "traefik.http.routers.mixpost.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.mixpost.entrypoints=web,websecure",
        "traefik.http.routers.mixpost.tls.certresolver=rb",
      ]
    }


    task "app" {
      driver = "docker"

      config {
        image = "inovector/mixpost-pro-team:latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/www/html/storage/app"
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
LICENSE_KEY = {{ key "mixpost/license/key" }}

APP_NAME    = "Redbrick Mixpost"

APP_KEY     = {{ key "mixpost/app/key" }}
APP_DOMAIN  = {{ env "NOMAD_META_domain" }}
APP_URL     = https://{{ env "NOMAD_META_domain" }}
APP_DEBUG   = false

DB_HOST     = {{ env "NOMAD_IP_db" }}
DB_PORT     = {{ env "NOMAD_HOST_PORT_db" }}
DB_DATABASE = {{ key "mixpost/db/name" }}
DB_USERNAME = {{ key "mixpost/db/user" }}
DB_PASSWORD = {{ key "mixpost/db/password" }}

REDIS_HOST  = {{ env "NOMAD_IP_redis" }}
REDIS_PORT  = {{ env "NOMAD_HOST_PORT_redis" }}

# MAIL_HOST=
# MAIL_PORT=
# MAIL_USERNAME=
# MAIL_PASSWORD=
# MAIL_ENCRYPTION=tls
# MAIL_FROM_ADDRESS = 
# MAIL_FROM_NAME=${APP_NAME}
# SSL_EMAIL

# POSSIBLE INTEGRATION WITH MINIO MORE RESEARCH NECESSARY
# MIXPOST_DISK=s3
EOH
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }

    task "redis" {
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

    task "db" {
      driver = "docker"

      config {
        image = "mariadb:latest"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/mysql",
          "local/server.cnf:/etc/mysql/mariadb.conf.d/50-server.cnf",
        ]
      }

      template {
        destination = "local/file.env"
        env         = true
        data        = <<EOH
MYSQL_DATABASE             = {{ key "mixpost/db/name" }}
MYSQL_USER                 = {{ key "mixpost/db/user" }}
MYSQL_PASSWORD             = {{ key "mixpost/db/password" }}
MYSQL_RANDOM_ROOT_PASSWORD = yes
EOH
      }

      template {
        destination = "local/server.cnf"
        data        = <<EOH
[mariadbd]

pid-file                 = /run/mysqld/mysqld.pid
basedir                  = /usr

bind-address             = 0.0.0.0

expire_logs_days         = 10

character-set-server     = utf8mb4
character-set-collations = utf8mb4=uca1400_ai_ci
EOH
      }

      resources {
        cpu    = 400
        memory = 800
      }
    }
  }
}
