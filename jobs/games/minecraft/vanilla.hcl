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
        "traefik.http.routers.vanilla-mc-bluemap.tls.certresolver=rb",
      ]
    }

    task "minecraft-vanilla" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server:java21-graalvm"
        ports = ["mc", "rcon", "bluemap"]
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
EULA                      = "TRUE"
TYPE                      = "PAPER"
VERSION                   = "1.21.11"
ICON                      = "https://docs.redbrick.dcu.ie/res/logo.png"
USE_MEOWICE_FLAGS         = true
USE_MEOWICE_GRAALVM_FLAGS = true
MAX_MEMORY                = 18G
MOTD                      = "LONG LIVE THE REDBRICK"
MAX_PLAYERS               = "32"
VIEW_DISTANCE             = "32"
ENABLE_RCON               = true
RCON_PASSWORD             = {{ key "games/mc/vanilla-mc/rcon/password" }}
SPAWN_PROTECTION          = "0"
# Auto-download plugins
SPIGET_RESOURCES          = 83581,62325,118271,28140,81534 # RHLeafDecay, GSit, GravesX, Luckperms, chunky
MODRINTH_PROJECTS         = datapack:no-enderman-grief,imageframe,bluemap,nochatreports-spigot-paper,datapack:players-drop-heads,viaversion,viabackwards #,bmarker,thizzyz-tree-feller
EOF
        destination = "local/.env"
        env         = true
      }
    }
  }
}
