job "minecraft" {
  datacenters = ["aperture"]
  type = "service"

  group "vanilla" {
    constraint {
        attribute = "${attr.unique.hostname}"
        value = "glados"
    }

    count = 1
    network {
      port "mc-vanilla-port" {
        static = 25565
        to = 25565
      }
      port "mc-vanilla-rcon" {
        to = 25575
      }
      #mode = "bridge"
    }

    service {
      name = "minecraft-vanilla"
    }

    task "minecraft-server" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server"
        ports = ["mc-vanilla-port","mc-vanilla-rcon"]
        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data/world"
        ]
      }

      resources {
        cpu    = 3000 # 500 MHz
        memory = 6144 # 6gb
      }

      env {
        EULA = "TRUE"
        MEMORY = "6G"
      }
    }
  }

  group "create-astral" {
    count = 1
    network {
      port "mc-astral-port" {
        static = 25566
        to = 25565
      }
      port "mc-astral-rcon" {
        to = 25575
      }
      mode = "bridge"
    }

    service {
      name = "minecraft-astral"
    }

    task "minecraft-astral" {
      driver = "docker"
      config {
        image = "ghcr.io/maxi0604/create-astral:main"
        ports = ["mc-astral-port","mc-astral-rcon"]
        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data/world"
        ]
      }

      resources {
        cpu    = 3000 # 500 MHz
        memory = 8168 # 8gb
      }

      env {
        EULA = "TRUE"
        MEMORY = "6G"
      }
    }
  }
}
