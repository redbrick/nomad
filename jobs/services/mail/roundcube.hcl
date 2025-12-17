job "roundcube" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "webmail.redbrick.dcu.ie"
  }

  group "roundcube" {
    count = 1

    network {
      port "http" {
        to = 80
      }
      port "fpm" {
        to = 9000
      }
      port "db" {
        to = 5432
      }
    }

    service {
      name = "roundcube-web"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.roundcube.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.roundcube.entrypoints=web,websecure",
        "traefik.http.routers.roundcube.tls.certresolver=lets-encrypt",
      ]
    }

    task "roundcube-nginx" {
      driver = "docker"

      config {
        image    = "nginx:alpine"
        ports    = ["http"]
        hostname = "${NOMAD_META_domain}"
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/roundcube:/var/www/html:ro",
          "local/nginx.conf:/etc/nginx/conf.d/default.conf:ro"
        ]
      }
      template {
        destination = "local/nginx.conf"
        data        = <<EOH
server {
    index index.php index.html;
    server_name {{ env "NOMAD_META_domain" }};
    error_log  /var/log/nginx/error.log;
    access_log /var/log/nginx/access.log;
    root /var/www/html/public_html;

    location ~ /(temp|logs)/ {
        deny all;
        return 403;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass {{ env "NOMAD_ADDR_fpm" }};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }
}
EOH
      }
    }

    task "roundcube" {
      driver = "docker"

      config {
        image = "roundcube/roundcubemail:1.6.x-fpm-alpine"
        ports = ["fpm"]

        hostname = "${NOMAD_META_domain}"

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/www/html",
          "local/rb-custom.php:/var/roundcube/config/rb-custom.php"
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
ROUNDCUBEMAIL_DB_TYPE=pgsql
ROUNDCUBEMAIL_DB_HOST={{ env "NOMAD_IP_db" }}
ROUNDCUBEMAIL_DB_PORT={{ env "NOMAD_HOST_PORT_db" }}
ROUNDCUBEMAIL_DB_NAME={{ key "roundcube/db/name" }}
ROUNDCUBEMAIL_DB_USER={{ key "roundcube/db/user" }}
ROUNDCUBEMAIL_DB_PASSWORD={{ key "roundcube/db/password" }}

ROUNDCUBEMAIL_SKIN=elastic2022
ROUNDCUBEMAIL_DEFAULT_HOST=ssl://{{ key "roundcube/imap/host" }}
ROUNDCUBEMAIL_DEFAULT_PORT={{ key "roundcube/imap/port" }}
ROUNDCUBEMAIL_SMTP_SERVER=tls://{{ key "roundcube/smtp/host" }}
ROUNDCUBEMAIL_SMTP_PORT={{ key "roundcube/smtp/port" }}
ROUNDCUBEMAIL_USERNAME_DOMAIN=redbrick.dcu.ie

ROUNDCUBEMAIL_INSTALL_PLUGINS=true
ROUNDCUBEMAIL_PLUGINS=archive,zipdownload,attachment_reminder,enigma,emoticons,identity_select,identicon,jqueryui,hide_blockquote,userinfo,markasjunk,additional_message_headers,newmail_notifier,thunderbird_labels,show_folder_size,tls_icon,vcard_attachments
ROUNDCUBEMAIL_COMPOSER_PLUGINS=weird-birds/thunderbird_labels,jfcherng-roundcube/show-folder-size,germancoding/tls_icon,roundcube/larry,roundcube/classic,seb1k/elastic2022
EOH
      }
      template {
        destination = "local/rb-custom.php"
        data        = <<EOH
<?php
        // Redbrick Roundcube custom config overrides
$config['product_name'] = 'Redbrick Webmail';
$config['skin_logo'] = 'https://raw.githubusercontent.com/redbrick/design-system/main/assets/logos/redbrick.svg';
$config['support_url'] = 'https://redbrick.dcu.ie/';

EOH
      }
    }

    task "roundcube-db" {
      driver = "docker"

      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/postgresql/data"
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
POSTGRES_PASSWORD={{ key "roundcube/db/password" }}
POSTGRES_USER={{ key "roundcube/db/user" }}
POSTGRES_DB={{ key "roundcube/db/name" }}
EOH
      }
    }
  }
}
