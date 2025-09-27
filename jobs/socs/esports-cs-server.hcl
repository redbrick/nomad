job "esports-cs2" {
  datacenters = ["aperture"]
  type        = "service"

  group "cs2-server" {
    count = 1

    network {
      port "game" {
        to = 27015
      }
      port "tv" {
        to = 27020
      }
      port "rcon" {
        to = 27015
      }
    }

    # service {
    #   name = "cs2-rcon"
    #   port = "rcon"
    #   tags = [
    #     "traefik.enable=true",
    #     "traefik.tcp.routers.cs2-rcon.rule=HostSNI(`cs2.rb.dcu.ie`)",
    #     "traefik.tcp.routers.cs2-rcon.entrypoints=cs2",
    #   ]
    # }

    service {
      name = "cs2-server"
      port = "game"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.cs2-server.rule=Host(`cs2.rb.dcu.ie`)",
        "traefik.http.routers.cs2-server.entrypoints=cs2",
      ]
    }

    task "cs2-server" {
      driver = "docker"
      
      config {
        image = "cm2network/cs2:latest"
        ports = ["game", "rcon", "tv"]
        
        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}/game:/home/steam/cs2-dedicated",
          "/storage/nomad/${NOMAD_TASK_NAME}/matchzy:/home/steam/cs2-dedicated/csgo/cfg/matchzy"
        ]
      }

      resources {
        cpu    = 8000
        memory = 20000
      }

      template {
        data = <<EOF
# Server Identity
SRCDS_TOKEN="{{ key "games/cs2/auth-token" }}"
CS2_SERVERNAME="Esports CS2 Server"
CS2_LAN="0"

# Game Configuration
CS2_GAMEALIAS="competitive"
CS2_MAXPLAYERS="24"
CS2_MAPGROUP="mg_active"
CS2_STARTMAP="de_dust2"

# Security
CS2_RCONPW="{{ key "games/cs2/rcon-password" }}"
CS2_PW="{{ key "games/cs2/server-password" }}"

# Performance
CS2_SERVER_HIBERNATE="0"
CS2_ADDITIONAL_ARGS="-usercon -secure -net_port_try 1"

# MatchZY Configuration
MATCHZY_CFG="/home/steam/cs2-dedicated/csgo/cfg/matchzy/matchzy.cfg"

# CSTV Configuration
TV_ENABLE="1"
TV_PORT="27020"
TV_PW="{{ key "games/cs2/tv-password" }}"

# Workshop Support
STEAMAPPVALIDATE="1"
EOF
        destination = "local/.env"
        env         = true
      }

      template {
        data = <<EOF
// MatchZY Competitive Configuration
matchzy_enable "1"
matchzy_knife_round "1"
matchzy_auto_ready "1"
matchzy_auto_knife "1"
matchzy_auto_lo3 "1"

// Competitive Ruleset
mp_competitive_endofmatch_extra_time "15"
mp_maxrounds "24"
mp_overtime_enable "1"
mp_overtime_maxrounds "6"
EOF
        destination = "local/matchzy.cfg"
      }
    }
  }
}
