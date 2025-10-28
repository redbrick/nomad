job "dcusr-rocketchat" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "chat.solarracing.ie"
  }

  group "rocketchat" {
    count = 1

    network {
      port "http" {
        to = 3000
      }
      port "db" {
        to = 27017
      }
    }

    restart {
      attempts = 20
      delay    = "10s"
      interval = "10m"
      mode     = "delay"
    }

    service {
      name = "rocketchat"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.dcusr-rocketchat.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.dcusr-rocketchat.tls=true",
        "traefik.http.routers.dcusr-rocketchat.entrypoints=web,websecure",
        "traefik.http.routers.dcusr-rocketchat.tls.certresolver=lets-encrypt",
      ]
    }

    task "init-mongo-perms" {
      driver = "docker"
      lifecycle {
        hook = "prestart"
      }
      restart {
        attempts = 0
      }

      config {
        image   = "alpine:3"
        command = "sh"
        args    = ["-lc", "mkdir -p /data && chown -R 1001:1001 /data && chmod -R u+rwX,g+rwX /data"]
        volumes = ["/storage/nomad/${NOMAD_JOB_NAME}/mongodb:/data"]
      }

      resources {
        cpu = 50
        memory = 64
      }
    }

    task "mongodb" {
      driver = "docker"

      config {
        image = "docker.io/bitnamilegacy/mongodb:8.0.13"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/mongodb:/bitnami/mongodb"
        ]
      }

      template {
        destination = "local/mongo.env"
        env         = true
        data = <<EOH
MONGODB_REPLICA_SET_MODE=primary
MONGODB_REPLICA_SET_NAME=rs0
MONGODB_PORT_NUMBER=27017
MONGODB_INITIAL_PRIMARY_HOST=127.0.0.1
MONGODB_INITIAL_PRIMARY_PORT_NUMBER=27017
MONGODB_ADVERTISED_HOSTNAME=localhost
MONGODB_ENABLE_JOURNAL=true
ALLOW_EMPTY_PASSWORD=yes
EOH
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }

      task "rocketchat" {
        driver = "docker"

        config {
          image = "registry.rocket.chat/rocketchat/rocket.chat:latest"
          ports = ["http"]
        }

        template {
          destination = "local/app.env"
          env         = true
          data = <<EOH
MONGO_URL=mongodb://{{ env "NOMAD_ADDR_db" }}/rocketchat?replicaSet=rs0&directConnection=true&serverSelectionTimeoutMS=60000&connectTimeoutMS=30000
MONGO_OPLOG_URL=mongodb://{{ env "NOMAD_ADDR_db" }}/local?replicaSet=rs0&directConnection=true

ROOT_URL=https://{{ env "NOMAD_META_domain" }}
PORT=3000
DEPLOY_METHOD=docker

WEB_PROCESS_COUNT=1
EOH
        }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }
}
