job "minecraft" {
  datacenters = ["aperture"]
  type = "service"

  group "vanilla-mc" {
    count = 1

    network {
      port "mc-vanilla-port" {
        static = 25567
        to = 25565
      }
      port "mc-vanilla-rcon" {
        to = 25575
      }
    }

    service {
      name = "vanilla-mc"
    }

    task "minecraft-server" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server"
        ports = ["mc-vanilla-port","mc-vanilla-rcon"]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 7168 # 7gb
      }

      env {
        EULA = "TRUE"
        MEMORY = "6G"
      }
    }
  }

  group "fugitives-mc" {
    count = 1

    network {
      port "mc-fugitives-port" {
        static = 25566
        to = 25565
      }

      port "mc-fugitives-rcon" {
        to = 25575
      }
    }

    service {
      name = "fugitives-mc"
    }

    task "minecraft-fugitives" {
      driver = "docker"

      config {
        image = "itzg/minecraft-server"
        ports = ["mc-fugitives-port","mc-fugitives-rcon"]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 8168 # 8gb
      }

      env {
        EULA = "TRUE"
        MEMORY = "6G"
      }
    }
  }
}
