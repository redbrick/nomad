job "minecraft-olim909" {
  datacenters = ["aperture"]
  type        = "service"

  group "olim909-mc" {
    count = 1

    network {
      port "mc" {
        to     = 25565
      }

      port "rcon" {
        to = 25575
      }
      port "geyser" {
        to = 19132
      }
    }

    service {
      name = "olim909-mc"
      port = "mc"
    }

    service {
      name = "olim909-mc-rcon"
      port = "rcon"
    }

    task "minecraft-olim909" {
      driver = "docker"

      config {
        image = "itzg/minecraft-server"
        ports = ["mc", "rcon", "geyser"]

        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 4096 # 4GB
      }

      env {
        EULA            = "TRUE"
        TYPE            = "PAPER"
        VERSION         = "1.20.4"
        USE_AIKAR_FLAGS = true
        OPS             = "Olim909"
        MAX_PLAYERS     = "5"
      }
    }
  }
}
