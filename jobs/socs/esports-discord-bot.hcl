job "esports-discord-bot" {
  datacenters = ["aperture"]
  type = "service"

  group "esports-bot" {
    count = 1

    network {
      port "db" {
        to = 27017
      }
    }

    task "esports-bot" {
      driver = "docker"

      config {
        image = "ghcr.io/aydenjahola/discord-multipurpose-bot:main"
        force_pull = true
      }

      resources {
        cpu = 500
        memory = 256
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
BOT_TOKEN={{ key "socs/esports/bot/discord/token" }}

EMAIL_NAME={{ key "socs/esports/bot/email/name" }}
EMAIL_PASS={{ key "socs/esports/bot/email/pass" }}
EMAIL_USER={{key "socs/esports/bot/email/user" }}

MONGODB_URI=mongodb://{{ key "socs/esports/bot/mongodb/username" }}:{{ key "socs/esports/bot/mongodb/password" }}@{{ env "NOMAD_ADDR_db" }}/?retryWrites=true&w=majority&appName={{ key "socs/esports/bot/mongodb/name" }}
EOH
      }
    }

    task "mongodb" {
      driver = "docker"

      config {
        image = "mongo:latest"

        ports = ["db"]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
MONGO_INITDB_ROOT_USERNAME="{{ key "socs/esports/bot/mongodb/username" }}"
MONGO_INITDB_ROOT_PASSWORD="{{ key "socs/esports/bot/mongodb/password" }}"
EOH
      }

      resources {
        cpu = 300
        memory = 512
      }
    }
  }
}
