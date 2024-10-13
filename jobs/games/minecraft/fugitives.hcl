job "minecraft-fugitives" {
  datacenters = ["aperture"]
  type        = "service"

  group "fugitives-mc" {
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
      name = "fugitives-mc"
      port = "mc"
    }

    service {
      name = "fugitives-mc-rcon"
      port = "rcon"
    }

    task "minecraft-fugitives" {
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
USE_AIKAR_FLAGS = true
MOTD            = "Fugitives"
MAX_PLAYERS     = "20"
MEMORY          = "6G"
ENABLE_RCON     = true
RCON_PASSWORD   = {{ key "games/mc/fugitives-mc/rcon/password" }}
EOF
        destination = "local/.env"
        env         = true
      }
    }
  }
}
