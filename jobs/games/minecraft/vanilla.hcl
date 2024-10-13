job "minecraft-vanilla" {
  datacenters = ["aperture"]
  type        = "service"

  group "vanilla-mc" {
    count = 1

    network {
      port "mc" {
        to = 25565
      }
      port "rcon" {
        to = 25575
      }
    }

    service {
      name = "vanilla-mc"
      port = "mc"
    }

    service {
      name = "vanilla-mc-rcon"
      port = "rcon"
    }

    task "minecraft-vanilla" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server"
        ports = ["mc", "rcon"]
        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 8192 # 8GB
      }

      template {
        data        = <<EOF
EULA            = "TRUE"
TYPE            = "PAPER"
VERSION         = "1.21.1"
ICON            = "https://docs.redbrick.dcu.ie/assets/logo.png"
USE_AIKAR_FLAGS = true
MOTD            = "LONG LIVE THE REDBRICK"
MAX_PLAYERS     = "20"
ENABLE_RCON     = true
RCON_PASSWORD   = {{ key "games/mc/vanilla-mc/rcon/password" }}
EOF
        destination = "local/.env"
        env         = true
      }
    }
  }
}
