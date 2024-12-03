job "blockbot" {
  datacenters = ["aperture"]

  type = "service"

  group "blockbot" {
    count = 1

    task "blockbot" {
      driver = "docker"

      config {
        image = "ghcr.io/redbrick/blockbot"
      }

      resources {
        cpu = 500
        memory = 256
      }

      template {
        data = <<EOF
TOKEN={{ key "blockbot/discord/token" }}
DEBUG= # empty means false
EOF
        destination = "local/.env"
        env = true
      }
    }
  }
}
