job "minecraft-magma" {
  datacenters = ["aperture"]
  type        = "service"

  group "fabric-server" {
    count = 1

    network {
      port "minecraft" {
        static = 25572
        to     = 25565
      }
      port "rcon" {
        to = 25575
      }
      port "voicechat" {
        to = 24454
      }
    }

    service {
      name = "minecraft-magma"
      port = "minecraft"
    }

    task "minecraft-magma" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server:java17-alpine"
        ports = ["minecraft", "rcon", "voicechat"]
        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 3000  # 3GHz
        memory = 10240 # 10GB
      }

      env {
        EULA            = "TRUE"
        TYPE            = "FABRIC"
        VERSION         = "1.20.4"
        ICON            = "https://raw.githubusercontent.com/redbrick/design-system/main/assets/logos/logo.png"
        MEMORY          = "8G"
        USE_AIKAR_FLAGS = true
        JVM_XX_OPTS     = "-XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 -XX:G1MaxNewSizePercent=40 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1NewSizePercent=30 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15 -XX:MaxGCPauseMillis=200 -XX:MaxTenuringThreshold=1 -XX:SurvivorRatio=32"
      }
    }
  }
}
