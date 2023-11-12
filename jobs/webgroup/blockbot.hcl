job "blockbot" {
  datacenters = ["aperture"]

  type = "service"

  group "blockbot" {
    count = 1

    task "blockbot" {
      driver = "docker"

      config {
        image = "ghcr.io/redbrick/blockbot"
        entrypoint = ["python3", "src/main.py"]
      }

      resources {
        cpu = 500
        memory = 256
      }

      template {
        data = <<EOF
TOKEN={{ key "blockbot/discord/token" }}
DEBUG=false
EOF
        destination = "local/.env"
        env = true
      }
    }
  }
}
