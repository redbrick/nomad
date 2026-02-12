job "matrix-element" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "matrix.redbrick.dcu.ie"
    main   = "redbrick.dcu.ie"
  }

  group "element" {
    count = 1

    network {

      port "http" {
        to = 80
      }
    }

    service {
      name = "element-web"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.element.rule=Host(`matrix.redbrick.dcu.ie`)",
        "traefik.http.routers.element.entrypoints=websecure",
        "traefik.http.routers.element.tls=true",
        "traefik.http.routers.element.tls.certresolver=rb",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "element" {
      driver = "docker"

      config {
        image = "vectorim/element-web:latest"
        ports = ["http"]

        volumes = [
          "local/config.json:/app/config.json:ro"
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }

      template {
        destination = "local/config.json"
        change_mode = "restart"
        data        = <<EOH
{
  "default_server_config": {
    "m.homeserver": {
      "base_url": "https://{{ env "NOMAD_META_domain" }}",
      "server_name": "{{ env "NOMAD_META_main" }}"
    },
    "m.identity_server": {
      "base_url": "https://vector.im"
    }
  },
  "brand": "Redbrick Matrix",
  "default_country_code": "IE",
  "show_labs_settings": true,
  "disable_custom_urls": false,
  "disable_guests": true,
  "disable_login_language_selector": false,
  "disable_3pid_login": false,
  "permalink_prefix": "https://{{ env "NOMAD_META_domain" }}",
  "room_directory": {
    "servers": [
      "redbrick.dcu.ie",
      "matrix.org",
      "fosdem.org"
    ]
  },
  "enable_presence_by_hs_url": {
    "https://{{ env "NOMAD_META_domain" }}": false
  },
  "setting_defaults": {
    "latex_maths": true,
    "pinning": true,
    "custom_themes": [
      {
    "name": "ThomCat black theme",
    "is_dark": true,
    "colors": {
        "accent-color": "#cc7b19",
        "primary-color": "#9F8652",
        "warning-color": "#f9c003",
        "sidebar-color": "#000000",
        "roomlist-background-color": "#191919",
        "roomlist-text-color": "#cc7b19",
        "roomlist-text-secondary-color": "#e5e5e5",
        "roomlist-highlights-color": "#323232",
        "roomlist-separator-color": "#4c4c4c",
        "timeline-background-color": "#000000",
        "timeline-text-color": "#e5e5e5",
        "secondary-content": "#e5e5e5",
        "tertiary-content": "#e5e5e5",
        "timeline-text-secondary-color": "#b2b2b2",
        "timeline-highlights-color": "#212121",
        "reaction-row-button-selected-bg-color": "#cc7b19"
    }
  },
  {
    "name": "Discord Dark",
    "is_dark": true,
    "colors": {
        "accent-color": "#747ff4",
        "accent": "#747ff4",
        "primary-color": "#00aff4",
        "warning-color": "#faa81ad9",
        "alert": "#faa81ad9",

        "sidebar-color": "#202225",
        "roomlist-background-color": "#2f3136",
        "roomlist-text-color": "#dcddde",
        "roomlist-text-secondary-color": "#8e9297",
        "roomlist-highlights-color": "#4f545c52",
        "roomlist-separator-color": "#40444b",

        "timeline-background-color": "#36393f",
        "timeline-text-color": "#dcddde",
        "secondary-content": "#dcddde",
        "tertiary-content": "#dcddde",
        "timeline-text-secondary-color": "#b9bbbe",
        "timeline-highlights-color": "#04040512",

        "reaction-row-button-selected-bg-color": "#4752c4",
        "menu-selected-color": "#4752c4",
        "focus-bg-color": "#4752c4",
        "room-highlight-color": "#4752c4",
        "other-user-pill-bg-color": "#4752c4",
        "togglesw-off-color": "#72767d"
    },
    "compound": {
        "--cpd-color-theme-bg": "#0019ff",
        "--cpd-color-bg-canvas-default": "#2f3136",
        "--cpd-color-bg-subtle-secondary": "#2f3136",
        "--cpd-color-bg-subtle-primary": "#4f545c52",
        "--cpd-color-bg-action-primary-rest": "#dcddde",
        "--cpd-color-bg-action-secondary-rest": "#2f3136",
        "--cpd-color-bg-critical-primary": "#fd3f3c",
        "--cpd-color-bg-critical-subtle": "#745862",
        "--cpd-color-bg-critical-hovered": "#fd3f3c",
        "--cpd-color-bg-accent-rest": "#4cb387",
        "--cpd-color-text-primary": "#dcddde",
        "--cpd-color-text-secondary": "#b9bbbe",
        "--cpd-color-text-action-accent": "#b9bbbe",
        "--cpd-color-text-critical-primary": "#fd3f3c",
        "--cpd-color-text-success-primary": "#4cb387",
        "--cpd-color-icon-primary": "#dcddde",
        "--cpd-color-icon-secondary": "#dcddde",
        "--cpd-color-icon-tertiary": "#a7a0a7",
        "--cpd-color-icon-accent-tertiary": "#4cb387",
        "--cpd-color-border-interactive-primary": "#5d6064",
        "--cpd-color-border-interactive-secondary": "#5d6064",
        "--cpd-color-border-critical-primary": "#fd3f3c",
        "--cpd-color-border-success-subtle": "#4cb387"
    }
  },
  {
    "name": "Discord Black",
    "is_dark": true,
    "colors": {
        "accent-color": "#747ff4",
        "accent": "#747ff4",
        "primary-color": "#00aff4",
        "warning-color": "#faa81ad9",
        "alert": "#faa81ad9",

        "sidebar-color": "#000000",
        "roomlist-background-color": "#191919",
        "roomlist-text-color": "#dcddde",
        "roomlist-text-secondary-color": "#8e9297",
        "roomlist-highlights-color": "#4f545c52",
        "roomlist-separator-color": "#40444b",

        "timeline-background-color": "#000000",
        "timeline-text-color": "#dcddde",
        "secondary-content": "#dcddde",
        "tertiary-content": "#dcddde",
        "timeline-text-secondary-color": "#b9bbbe",
        "timeline-highlights-color": "#04040512",

        "reaction-row-button-selected-bg-color": "#4752c4",
        "menu-selected-color": "#4752c4",
        "focus-bg-color": "#4752c4",
        "room-highlight-color": "#4752c4",
        "other-user-pill-bg-color": "#4752c4",
        "togglesw-off-color": "#72767d"
    }
}
        ]
    },
  "features": {
    "feature_pinning": "labs",
    "feature_custom_status": "labs",
    "feature_custom_tags": "labs",
    "feature_state_counters": "labs"
  }
}
EOH
      }
    }
  }
}
