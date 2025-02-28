job "esports-discord-bot" {
  datacenters = ["aperture"]
  type = "service"

  group "esports-bot" {
    count = 1

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
HUGGING_FACE_API_KEY={{ key "socs/esports/bot/huggingface/key" }}

RCON_HOST=esports-mc-rcon.service.consul

# https://discuss.hashicorp.com/t/passing-registered-ip-and-port-from-consul-to-env-nomad-job-section/35647
{{ range service "esports-mc-rcon" }}
RCON_PORT={{ .Port }}{{ end }}

RCON_PASSWORD={{ key "games/mc/esports-mc/rcon/password" }}
EOH
        destination = "local/.env"
        env = true
      }
    }
  }
}
