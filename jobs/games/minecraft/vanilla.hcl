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
      port "bluemap" {
        to = 8100
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

    service {
      name = "vanilla-mc-bluemap"
      port = "bluemap"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.vanilla-mc-bluemap.rule=Host(`vanilla-mc.rb.dcu.ie`)",
        "traefik.http.routers.vanilla-mc-bluemap.entrypoints=web,websecure",
        "traefik.http.routers.vanilla-mc-bluemap.tls.certresolver=lets-encrypt",
      ]
    }

    task "minecraft-vanilla" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server"
        ports = ["mc", "rcon", "bluemap"]
        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 5000  # 5000 MHz
        memory = 12288 # 12GB
      }

      template {
        data        = <<EOF
EULA            = "TRUE"
TYPE            = "PAPER"
VERSION         = "1.21.1"
ICON            = "https://docs.redbrick.dcu.ie/assets/logo.png"
USE_AIKAR_FLAGS = true
MAX_MEMORY      = 11G
MOTD            = "LONG LIVE THE REDBRICK"
MAX_PLAYERS     = "20"
VIEW_DISTANCE   = "20"
ENABLE_RCON     = true
RCON_PASSWORD   = {{ key "games/mc/vanilla-mc/rcon/password" }}
# Auto-download plugins
SPIGET_RESOURCES=83581,62325,118271,28140,102931 # RHLeafDecay, GSit, GravesX, Luckperms, NoChatReport
MODRINTH_PROJECTS=datapack:no-enderman-grief,thizzyz-tree-feller,imageframe,bluemap,bmarker,datapack:players-drop-heads,viaversion,viabackwards
EOF
        destination = "local/.env"
        env         = true
      }
    }
  }
}
