job "minecraft-magma" {
  datacenters = ["aperture"]
  type        = "service"

  group "fabric-server" {
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
      name = "magma-mc"
      port = "mc"
    }

    service {
      name = "magma-mc-rcon"
      port = "rcon"
    }

    service {
      name = "magma-mc-voice"
      port = "voice"
      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.magma-mc-voice.rule=HostSNI(`magma-mc.rb.dcu.ie`)",
        "traefik.tcp.routers.magma-mc-voice.tls.passthrough=true",
        "traefik.udp.routers.magma-mc-voice.entrypoints=voice-udp",
      ]
    }

    task "minecraft-magma" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server:java17-alpine"
        ports = ["mc", "rcon", "voice"]
        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 3000  # 3GHz
        memory = 10240 # 10GB
      }

      template {
        data        = <<EOF
EULA            = "TRUE"
TYPE            = "FABRIC"
VERSION         = "1.20.4"
ICON            = "https://raw.githubusercontent.com/redbrick/design-system/main/assets/logos/logo.png"
MEMORY          = "8G"
USE_AIKAR_FLAGS = true
JVM_XX_OPTS     = "-XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 -XX:G1MaxNewSizePercent=40 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1NewSizePercent=30 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15 -XX:MaxGCPauseMillis=200 -XX:MaxTenuringThreshold=1 -XX:SurvivorRatio=32"
ENABLE_RCON=true
RCON_PASSWORD   = {{{ key "games/mc/magma-mc/rcon/password" }}
EOF
        destination = "local/.env"
        env         = true
      }
    }
  }
}
