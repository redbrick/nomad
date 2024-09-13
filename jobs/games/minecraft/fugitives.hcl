job "minecraft-fugitives" {
  datacenters = ["aperture"]
  type        = "service"

  group "fugitives-mc" {
    count = 1

    network {
      port "mc" {
        static = 25570
        to     = 25565
      }
      port "rcon" {
        to = 25575
      }
    }

    service {
      name = "fugitives-mc"
      port = "mc"
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

      env {
        EULA            = "TRUE"
        TYPE            = "PAPER"
        USE_AIKAR_FLAGS = true
        MOTD            = "Fugitives"
        MAX_PLAYERS     = "20"
        MEMORY          = "6G"
      }
    }
  }
}
