job "ayden-discord-bot" {
  datacenters = ["aperture"]
  type = "service"

  group "discordbotgoml" {
    count = 1

    task "discordbotgoml" {
      driver = "docker"

      config {
        image = "ghcr.io/aydenjahola/discordbotgoml:main"
        force_pull = true
        auth {
          username = "${DOCKER_USER}"
          password = "${DOCKER_PASS}"
        }
      }

      resources {
        cpu = 500
        memory = 256
      }

      template {
        data = <<EOH
DISCORD_TOKEN={{ key "user-projects/ayden/gomlbot/discord/token" }}
DOCKER_USER={{ key "user-projects/ayden/ghcr/username" }}
DOCKER_PASS={{ key "user-projects/ayden/ghcr/password" }}
DEBUG=false
MONGO_DB={{ key "user-projects/ayden/gomlbot/mongo/db" }}
EOH
        destination = "local/.env"
        env = true
      }
    }
  }
}
