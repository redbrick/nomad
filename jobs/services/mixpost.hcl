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
        "traefik.http.routers.mixpost.tls.certresolver=mytlschallenge",
        "traefik.http.middlewares.mixpost.headers.SSLRedirect=true",
        "traefik.http.middlewares.mixpost.headers.STSSeconds=315360000",
        "traefik.http.middlewares.mixpost.headers.browserXSSFilter=true",
        "traefik.http.middlewares.mixpost.headers.contentTypeNosniff=true",
        "traefik.http.middlewares.mixpost.headers.forceSTSHeader=true",
        "traefik.http.middlewares.mixpost.headers.SSLHost=`${APP_DOMAIN}`",
        "traefik.http.middlewares.mixpost.headers.STSIncludeSubdomains=true",
        "traefik.http.middlewares.mixpost.headers.STSPreload=true"
      ]
    }


    task "mixpost" {
      driver = "docker"

      config {
        image = "inovector/mixpost:latest"
      ports = ["http"]
      }

      template {
        data        = <<EOH
APP_NAME=MIXPOST

APP_KEY={{ key "mixpost/APP_KEY" }}
APP_DEBUG=true
APP_DOMAIN=${NOMAD_META_domain}
APP_URL=https://${APP_DOMAIN}

DB_HOST={{ env "NOMAD_IP_db" }}
DB_PORT={{ env "NOMAD_HOST_PORT_db" }}
DB_DATABASE={{ key "mixpost/db/name" }}
DB_USERNAME={{ key "mixpost/db/user" }}
DB_PASSWORD={{ key "mixpost/db/password" }}
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
          "/storage/nomad/mixpost/mysql:/var/lib/mysql",
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
