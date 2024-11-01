job "esports-discord-bot" {
  datacenters = ["aperture"]
  type = "service"

  group "esports-bot" {
    count = 1

    task "esports-bot" {
      driver = "docker"

      config {
        image = "ghcr.io/aydenjahola/discord-multipurpose-bot:main"
      }

      resources {
        cpu = 500
        memory = 256
      }

      template {
        data = <<EOH
BOT_TOKEN={{ key "socs/esports/bot/discord/token" }}
EMAIL_NAME={{ key "socs/esports/bot/email/name" }}
EMAIL_PASS={{ key "socs/esports/bot/email/pass" }}
EMAIL_USER={{key "socs/esports/bot/email/user" }}
MONGODB_URI={{key "socs/esports/bot/mongodb/uri"}}
RAPIDAPI_KEY={{ key "socs/esports/bot/rapidapi/key" }}
TRACKER_API_KEY={{ key "socs/esports/bot/trackerapi/key" }}
TRACKER_API_URL={{ key "socs/esports/bot/trackerapi/url" }}
WORDNIK_API_KEY={{key "socs/esports/bot/wordnikapi/key" }}
EOH
        destination = "local/.env"
        env = true
      }
    }
  }
}
