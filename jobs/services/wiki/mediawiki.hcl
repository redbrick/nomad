job "mediawiki" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "wiki.redbrick.dcu.ie"
  }

  group "rbwiki" {
    count = 1

    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
      port "fpm" {
        to = 9000
      }
      port "db" {
        to = 3306
      }
    }

    service {
      name = "rbwiki-web"
      port = "http"

      check {
        type     = "http"
        path     = "/Main_Page"
        interval = "10s"
        timeout  = "5s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.rbwiki.rule=Host(`${NOMAD_META_domain}`) || Host(`wiki.rb.dcu.ie`)",
        "traefik.http.routers.rbwiki.entrypoints=web,websecure",
        "traefik.http.routers.rbwiki.tls.certresolver=rb",

        # attach all middlewares to the router
        "traefik.http.routers.rbwiki.middlewares=rbwiki-ratelimit,rbwiki-inflight,rbwiki-redirect-root,rbwiki-redirect-mw",

        # redirects
        "traefik.http.middlewares.rbwiki-redirect-root.redirectregex.regex=^https://wiki\\.redbrick\\.dcu\\.ie/?$",
        "traefik.http.middlewares.rbwiki-redirect-root.redirectregex.replacement=https://wiki.redbrick.dcu.ie/Main_Page",
        "traefik.http.middlewares.rbwiki-redirect-mw.redirectregex.regex=https://wiki\\.redbrick\\.dcu\\.ie/Mw/(.*)",
        "traefik.http.middlewares.rbwiki-redirect-mw.redirectregex.replacement=https://wiki.redbrick.dcu.ie/$1",

        # per-client rate limit
        "traefik.http.middlewares.rbwiki-ratelimit.ratelimit.average=20",
        "traefik.http.middlewares.rbwiki-ratelimit.ratelimit.period=1s",
        "traefik.http.middlewares.rbwiki-ratelimit.ratelimit.burst=40",

        # group requests by client IP
        "traefik.http.middlewares.rbwiki-ratelimit.ratelimit.sourcecriterion.ipstrategy.depth=1",

        # cap concurrent requests per client IP
        "traefik.http.middlewares.rbwiki-inflight.inflightreq.amount=10",
        "traefik.http.middlewares.rbwiki-inflight.inflightreq.sourcecriterion.ipstrategy.depth=1",
      ]
    }

    task "rbwiki-nginx" {
      driver = "docker"
      config {
        image = "nginx:alpine"
        ports = ["http"]
        volumes = [
          "local/nginx.conf:/etc/nginx/nginx.conf",
          "/storage/nomad/mediawiki/extensions:/var/www/html/extensions",
          "/storage/nomad/mediawiki/images:/var/www/html/images",
          "/storage/nomad/mediawiki/skins:/var/www/html/skins",
          "/storage/nomad/mediawiki/resources/assets:/var/www/html/Resources/assets",
        ]
      }
      resources {
        cpu    = 200
        memory = 100
      }
      template {
        destination = "local/nginx.conf"
        data        = <<EOH
# user www-data www-data;
error_log /dev/stderr error;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    server_tokens off;
    error_log /dev/stderr error;
    charset utf-8;

    # Trust only Traefik / ingress
    set_real_ip_from 136.206.16.50;
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;

    log_format main '$remote_addr realip=$realip_remote_addr xff="$http_x_forwarded_for" '
                    '- $remote_user [$time_local] "$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent"';
    access_log /dev/stdout main;

    # Per-IP limits
    limit_conn_zone $binary_remote_addr zone=perip_conn:10m;
    limit_req_zone  $binary_remote_addr zone=perip_req:10m rate=8r/s;
    limit_req_zone  $binary_remote_addr zone=perip_php:10m rate=3r/s;

    # Known crawler UAs you want to be harsher with
    map $http_user_agent $bad_bot {
        default 0;
        ~*(GPTBot|Amazonbot|SEOkicks|meta-externalagent) 1;
    }

    # Expensive MediaWiki special pages
    map $arg_title $is_bad_special {
        default 0;
        ~*^Special:(UserLogin|CreateAccount|RecentChanges|RecentChangesLinked|WhatLinksHere)$ 1;
    }

    # Expensive actions
    map $arg_action $is_bad_action {
        default 0;
        ~*^(edit|history|info|submit)$ 1;
    }

    # Composite flags
    map "$bad_bot:$is_bad_special" $block_bad_special {
        default 0;
        "1:1" 1;
    }

    map "$bad_bot:$is_bad_action" $block_bad_action {
        default 0;
        "1:1" 1;
    }

    server {
        server_name {{ env "NOMAD_META_domain" }};
        listen 80;
        listen [::]:80;
        root /var/www/html;
        index index.php index.html index.htm;

        client_max_body_size 5m;
        client_body_timeout 60;
        keepalive_timeout 15;
        send_timeout 30;

        limit_conn perip_conn 15;

        location / {
            limit_req zone=perip_req burst=15 nodelay;
            try_files $uri $uri/ @rewrite;
        }

        location @rewrite {
            limit_req zone=perip_req burst=15 nodelay;
            rewrite ^/(.*)$ /index.php?title=$1&$args;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|otf|eot)$ {
            try_files $uri /index.php;
            expires max;
            log_not_found off;
        }

        location = /index.php {
            limit_req zone=perip_php burst=5 nodelay;

            if ($is_bad_special) {
                return 429;
            }

            if ($is_bad_action) {
                return 429;
            }

            if ($block_bad_special) {
                return 403;
            }

            if ($block_bad_action) {
                return 403;
            }

            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param REMOTE_ADDR $remote_addr;
            fastcgi_param HTTP_X_REAL_IP $remote_addr;
            fastcgi_param HTTP_X_FORWARDED_FOR $http_x_forwarded_for;
            fastcgi_pass {{ env "NOMAD_HOST_ADDR_fpm" }};
            fastcgi_index index.php;

            fastcgi_connect_timeout 10s;
            fastcgi_send_timeout 30s;
            fastcgi_read_timeout 30s;
            fastcgi_buffering on;
            fastcgi_buffers 16 16k;
            fastcgi_buffer_size 32k;
        }

        location ~ \.php$ {
            limit_req zone=perip_php burst=5 nodelay;

            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param REMOTE_ADDR $remote_addr;
            fastcgi_param HTTP_X_REAL_IP $remote_addr;
            fastcgi_param HTTP_X_FORWARDED_FOR $http_x_forwarded_for;
            fastcgi_pass {{ env "NOMAD_HOST_ADDR_fpm" }};
            fastcgi_index index.php;

            fastcgi_connect_timeout 10s;
            fastcgi_send_timeout 30s;
            fastcgi_read_timeout 30s;
            fastcgi_buffering on;
            fastcgi_buffers 16 16k;
            fastcgi_buffer_size 32k;
        }

        location ~ /\.ht {
            deny all;
        }
    }
}
EOH
      }
    }

    task "rbwiki-php" {
      driver = "docker"

      config {
        image = "ghcr.io/wizzdom/mediawiki-fpm-ldap-alpine:latest"
        ports = ["fpm"]

        volumes = [
          "/storage/nomad/mediawiki/extensions:/var/www/html/extensions",
          "/storage/nomad/mediawiki/images:/var/www/html/images",
          "/storage/nomad/mediawiki/skins:/var/www/html/skins",
          "/storage/nomad/mediawiki/resources/assets:/var/www/html/Resources/assets",
          "local/php.ini:/usr/local/etc/php/php.ini",
          "local/LocalSettings.php:/var/www/html/LocalSettings.php",
          "local/ldapprovider.json:/etc/mediawiki/ldapprovider.json"
        ]
      }

      resources {
        cpu    = 4000
        memory = 1200
      }

      # php.ini file because php is ass and won't let you update this in LocalSettings.php
      template {
        destination = "local/php.ini" 
        data = <<EOH
post_max_size = 64M
upload_max_filesize = 50M
EOH
      }

      template {
        destination = "local/ldapprovider.json"
        data        = <<EOH
{
  "Redbrick": {
    "connection": {
      "server": "{{ range service "openldap-ldap" }}{{ .Address }}{{ end }}",
      "port": "{{ range service "openldap-ldap" }}{{ .Port }}{{ end }}",
      "user": "{{ key "mediawiki/ldap/user" }}",
      "pass": "{{ key "mediawiki/ldap/password" }}",
      "enctype": "clear",
      "basedn": "o=redbrick,dc=redbrick,dc=dcu,dc=ie",
      "groupbasedn": "ou=groups,o=redbrick,dc=redbrick,dc=dcu,dc=ie",
      "userbasedn": "ou=accounts,o=redbrick,dc=redbrick,dc=dcu,dc=ie",
      "searchattribute": "uid",
      "usernameattribute": "uid",
      "realnameattribute": "cn",
      "emailattribute": "mail",
      "options": {
        "LDAP_OPT_DEREF": 1
      },
      "grouprequest": "MediaWiki\\Extension\\LDAPProvider\\UserGroupsRequest\\UserMemberOf::factory"
    },
    "authorization": {
      "rules": {
        "groups": {
          "required": []
        }
      }
    }
  }
}
EOH
      }

      template {
        data        = file("LocalSettings.php")
        destination = "local/LocalSettings.php"
      }
    }

    service {
      name = "rbwiki-db"
      port = "db"

      check {
        name     = "mariadb_probe"
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "rbwiki-db" {
      driver = "docker"

      config {
        image = "mariadb:11.4"
        ports = ["db"]

        volumes = [
          "/storage/nomad/mediawiki/db:/var/lib/mysql",
          "/oldstorage/wiki_backups:/wiki-backups/backup",
          "local/conf.cnf:/etc/mysql/mariadb.conf.d/50-server.cnf",
        ]
      }

      template {
        destination = "local/conf.cnf"
        data        = <<EOH
[mysqld]
# Ensure full UTF-8 support
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
skip-character-set-client-handshake

# Fix 1000-byte key length issue
innodb_large_prefix = 1
innodb_file_format = Barracuda
innodb_file_per_table = 1
innodb_default_row_format = dynamic

# Performance optimizations (Keep these based on your system)
max_connections = 100
key_buffer_size = 2G
query_cache_size = 0
innodb_buffer_pool_size = 6G
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 1
innodb_flush_method = O_DIRECT
innodb_io_capacity = 200
tmp_table_size = 5242K
max_heap_table_size = 5242K
innodb_log_buffer_size = 16M

# Logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1

# Network
bind-address = 0.0.0.0
EOH
      }

      resources {
        cpu    = 800
        memory = 6144
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
MYSQL_DATABASE={{ key "mediawiki/db/name" }}
MYSQL_USER={{ key "mediawiki/db/username" }}
MYSQL_PASSWORD={{ key "mediawiki/db/password" }}
MYSQL_RANDOM_ROOT_PASSWORD=yes
EOH
      }
    }
  }
}
