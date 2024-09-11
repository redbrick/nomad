job "midnight-calendarbot" {
  datacenters = ["aperture"]
  type        = "service"

  group "calendarbot" {
    count = 1

    task "calendarbot" {
      driver = "docker"

      config {
        image      = "ghcr.io/nightmarishblue/calendarbot:latest"
        force_pull = true
      }

      template {
        data        = <<EOH
BOT_TOKEN={{ key "user-projects/midnight/calendarbot/discord/token" }}
APPLICATION_ID={{ key "user-projects/midnight/calendarbot/discord/appid" }}
EOH
        destination = "local/.env"
        env         = true
      }
    }
  }
}
