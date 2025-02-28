job "esports-minecraft" {
  datacenters = ["aperture"]
  type        = "service"

  group "esports-mc" {
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
      name = "esports-mc"
      port = "mc"
    }

    service {
      name = "esports-mc-rcon"
      port = "rcon"
    }

    task "esports-minecraft" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server"
        ports = ["mc", "rcon"]
        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 5000  # 5000 MHz
        memory = 20480 # 20 GB
      }

      template {
        data        = <<EOF
EULA            = "TRUE"
TYPE            = "PAPER"
VERSION         = "1.21.4"
ICON            = "https://liquipedia.net/commons/images/thumb/5/53/DCU_Esports_allmode.png/37px-DCU_Esports_allmode.png"
USE_AIKAR_FLAGS = true
MAX_MEMORY      = 18G
MOTD            = "Powered by Redbrick"
MAX_PLAYERS     = "32"
VIEW_DISTANCE   = "32"
ENABLE_RCON     = true
RCON_PASSWORD   = {{ key "games/mc/esports-mc/rcon/password" }}
# Auto-download plugins
SPIGET_RESOURCES=83581,62325,118271,28140,102931 # RHLeafDecay, GSit, GravesX, Luckperms, NoChatReport
MODRINTH_PROJECTS=datapack:no-enderman-grief,thizzyz-tree-feller,imageframe,bmarker,datapack:players-drop-heads,viaversion,viabackwards
EOF
        destination = "local/.env"
        env         = true
      }
    }
  }
}
