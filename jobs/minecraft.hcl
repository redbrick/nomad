job "minecraft" {
  datacenters = ["aperture"]
  type = "service"

#  group "vanilla" {
#    constraint {
#        attribute = "${attr.unique.hostname}"
#        value = "glados"
#    }
#
#    count = 1
#    network {
#      port "mc-vanilla-port" {
#        static = 25565
#        to = 25565
#      }
#      port "mc-vanilla-rcon" {
#        to = 25575
#      }
#      #mode = "bridge"
#    }
#
#    service {
#      name = "minecraft-vanilla"
#    }
#
#    task "minecraft-server" {
#      driver = "docker"
#      config {
#        image = "itzg/minecraft-server"
#        ports = ["mc-vanilla-port","mc-vanilla-rcon"]
#        volumes = [
#          "/storage/nomad/${NOMAD_TASK_NAME}:/data/world"
#        ]
#      }
#
#      resources {
#        cpu    = 3000 # 500 MHz
#        memory = 6144 # 6gb
#      }
#
#      env {
#        EULA = "TRUE"
#        MEMORY = "6G"
#      }
#    }
#  }

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

      #mode = "bridge"
    }

    service {
      name = "fugitives-mc"
    }

    task "minecraft-fugitives" {
      driver = "docker"

      config {
        image = "itzg/minecraft-server"
        ports = ["mc-fugitives-port","mc-fugitives-rcon"]
        #volumes = [
        #  "/storage/nomad/${NOMAD_TASK_NAME}:/data/world"
        #]
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
