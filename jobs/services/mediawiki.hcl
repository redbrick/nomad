job "mediawiki" {
  datacenters = ["aperture"]
  type = "service"

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
        type = "http"
        path = "/Main_Page"
        interval = "10s"
        timeout = "5s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.rbwiki.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.rbwiki.entrypoints=web,websecure",
        "traefik.http.routers.rbwiki.tls.certresolver=lets-encrypt",
        "traefik.http.routers.rbwiki.middlewares=redirect-short-url",
        "traefik.http.middlewares.redirect-short-url.redirectregex.regex=https://wiki\\.redbrick\\.dcu\\.ie/index\\.php\\?title=(.*)",
        "traefik.http.middlewares.redirect-short-url.redirectregex.replacement=https://wiki.redbrick.dcu.ie/$1",
        "traefik.http.routers.rbwiki.middlewares=redirect-root",
        "traefik.http.middlewares.redirect-root.redirectregex.regex=^https://wiki\\.redbrick\\.dcu\\.ie/?$",
        "traefik.http.middlewares.redirect-root.redirectregex.replacement=https://wiki.redbrick.dcu.ie/Main_Page",
        # "traefik.http.routers.rbwiki.middlewares=redirect-mw",
        # "traefik.http.middlewares.redirect-mw.redirectregex.regex=https://wiki\\.redbrick\\.dcu\\.ie/Mw/(.*)",
        # "traefik.http.middlewares.redirect-mw.redirectregex.replacement=https://wiki.redbrick.dcu.ie/$1",
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
        data = <<EOH
# user www-data www-data;
error_log /dev/stderr error;
events {
    worker_connections 1024;
}
http {
    include /etc/nginx/mime.types;
    server_tokens off;
    error_log /dev/stderr error;
    access_log /dev/stdout;
    charset utf-8;

    server {
      server_name {{ env "NOMAD_META_domain" }};
      listen 80;
      listen [::]:80;
      root /var/www/html;
      index index.php index.html index.htm;

      client_max_body_size 5m;
      client_body_timeout 60;

      # MediaWiki short URLs
      location / {
        try_files $uri $uri/ @rewrite;
      }

      location @rewrite {
        rewrite ^/(.*)$ /index.php?title=$1&$args;
      }

      location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|otf|eot|ico)$ {
        try_files $uri /index.php;
        expires max;
        log_not_found off;
      }

      # Pass the PHP scripts to FastCGI server
      location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass {{ env "NOMAD_HOST_ADDR_fpm" }};
        fastcgi_index index.php;
      }

      location ~ /\.ht {
        deny all;
      }
    }
}
EOH
        destination = "local/nginx.conf"
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
          "local/LocalSettings.php:/var/www/html/LocalSettings.php",
          "local/ldapprovider.json:/etc/mediawiki/ldapprovider.json"
        ]
      }

      resources {
          cpu    = 4000
          memory = 1200
        }

      template {
        data = <<EOH
{
  "LDAP": {
    "authorization": {
      "rules": {
        "groups": {
          "required": []
        }
      }
    },
    "connection": {
      "server": "{{ key "mediawiki/ldap/server" }}",
      "user": "{{ key "mediawiki/ldap/user" }}",
      "pass": "{{ key "mediawiki/ldap/password" }}",
      "options": {
        "LDAP_OPT_DEREF": 1
      },
      "grouprequest": "MediaWiki\\Extension\\LDAPProvider\\UserGroupsRequest\\GroupMemberUid::factory",
      "basedn": "o=redbrick",
      "groupbasedn": "ou=groups,o=redbrick",
      "userbasedn": "ou=accounts,o=redbrick",
      "searchattribute": "uid",
      "searchstring": "uid=USER-NAME,ou=accounts,o=redbrick",
      "usernameattribute": "uid",
      "realnameattribute": "cn",
      "emailattribute": "altmail"
    }
  }
}
EOH

        destination = "local/ldapprovider.json"
      }

      template {
        data = <<EOH
<?php
# Protect against web entry
if ( !defined( 'MEDIAWIKI' ) ) {
	exit;
}

$wgSitename = "Redbrick Wiki";

$wgScriptPath = "";
$wgArticlePath = "/$1";
$wgUsePathInfo = true;
$wgScriptExtension = ".php";

$wgServer = "https://{{ env "NOMAD_META_domain" }}";

## The URL path to static resources (images, scripts, etc.)
$wgResourceBasePath = $wgScriptPath;
$wgLogo = "$wgResourceBasePath/Resources/assets/logo.png";
$wgFavicon = "$wgResourceBasePath/Resources/assets/favicon.ico";
$wgAllowExternalImages = true;


## UPO: this is also a user preference option
$wgEnableEmail = false;
$wgEnableUserEmail = false; # UPO

$wgEmergencyContact = "{{ key "mediawiki/mail/emergency/contact" }}";
$wgPasswordSender = "{{ key "mediawiki/mail/password/sender" }}";

$wgEnotifUserTalk = false; # UPO
$wgEnotifWatchlist = false; # UPO
$wgEmailAuthentication = true;

## Database settings
$wgDBtype = "mysql";
$wgDBserver = "{{ env "NOMAD_ALLOC_IP_db" }}";
$wgDBport = "{{ env "NOMAD_ALLOC_PORT_db" }}";
$wgDBname = "{{ key "mediawiki/db/name" }}";
$wgDBuser = "{{ key "mediawiki/db/username" }}";
$wgDBpassword = "{{ key "mediawiki/db/password" }}";
# MySQL specific settings
$wgDBprefix = "rbwiki_";
# MySQL table options to use during installation or update
$wgDBTableOptions = "ENGINE=InnoDB, DEFAULT CHARSET=binary";

## Shared memory settings
$wgMainCacheType = CACHE_NONE;
$wgMemCachedServers = [];

$wgEnableUploads = true;
$wgUseImageMagick = true;
$wgImageMagickConvertCommand = "/usr/bin/convert";
$wgUploadPath = "$wgScriptPath/images";
$wgUploadDirectory = "{$IP}/images";
$wgHashedUploadDirectory = true;
$wgDirectoryMode = 0755;
umask(0022);

# InstantCommons allows wiki to use images from https://commons.wikimedia.org
$wgUseInstantCommons = false;

$wgPingback = false;

$wgShellLocale = "C.UTF-8";

$wgLanguageCode = "en";

$wgSecretKey = "{{ key "mediawiki/key/secret" }}";

# Changing this will log out all existing sessions.
$wgAuthenticationTokenVersion = "1";

# Site upgrade key. Must be set to a string (default provided) to turn on the
# web installer while LocalSettings.php is in place
$wgUpgradeKey = "{{ key "mediawiki/key/upgrade" }}";

$wgRightsPage = ""; # Set to the title of a wiki page that describes your license/copyright
$wgRightsUrl = "";
$wgRightsText = "";
$wgRightsIcon = "";

$wgDiff3 = "/usr/bin/diff3";

$wgDefaultSkin = "citizen";
$wgDefaultMobileSkin = 'citizen';

# Enabled skins.
wfLoadSkin( 'Vector' );
wfLoadSkin( 'Citizen' );
wfLoadSkin( 'Timeless' );
wfLoadSkin( 'MinervaNeue' );

$wgCitizenThemeColor = "#a81e22";
$wgCitizenShowPageTools = "permission";
$wgCitizenSearchDescriptionSource = "pagedescription";

$wgLocalisationUpdateDirectory = "$IP/cache";

# load extensions
wfLoadExtension( 'HitCounters' );
wfLoadExtension( 'LDAPProvider' );
wfLoadExtension( 'LDAPAuthentication2' );
wfLoadExtension( 'PluggableAuth' );
$wgPluggableAuth_ButtonLabel = "Redbrick Log In";
wfLoadExtension( 'LDAPAuthorization' );
wfLoadExtension( 'OpenGraphMeta' );
wfLoadExtension( 'Description2' );
$wgEnableMetaDescriptionFunctions = true;
wfLoadExtension( 'PageImages' );
$wgPageImagesOpenGraphFallbackImage = $wgLogo;
wfLoadExtension( 'Plausible' );
$wgPlausibleDomain = "https://plausible.redbrick.dcu.ie";
$wgPlausibleDomainKey = "wiki.redbrick.dcu.ie";
$wgPlausibleTrackOutboundLinks = true;
$wgPlausibleTrackLoggedIn = true;
$wgPlausibleTrack404 = true;
$wgPlausibleTrackSearchInput = true;
$wgPlausibleTrackCitizenSearchLinks = true;
$wgPlausibleTrackCitizenMenuLinks = true;
wfLoadExtension( 'WikiMarkdown' );
$wgAllowMarkdownExtra = true;
$wgAllowMarkdownExtended = true;
wfLoadExtension( 'RSS' );
wfLoadExtension( 'SyntaxHighlight_GeSHi' );
wfLoadExtension( 'WikiEditor' );
wfLoadExtension( 'MobileFrontend' );


$LDAPProviderDomainConfigs = "/etc/mediawiki/ldapprovider.json";

$wgPluggableAuth_Config['Redbrick Log In'] = [
    'plugin' => 'LDAPAuthentication2',
    'data' => [
        'domain' => 'LDAP'
    ],
];

# RBOnly Namespace
# To allow semi-public pages
$wgExtraNamespaces = array(100 => "RBOnly", 101 => "RBOnly_talk");
$wgNamespacesWithSubpages = array( -1 => 0, 0 => 0, 1 => 1, 2 => 1, 3 => 1, 4 => 0, 5 => 1, 6 => 0, 7 => 1, 8 => 0, 9 => 1, 10 => 0, 11 => 1,100 => 1,101 => 1);
$wgNamespacesToBeSearchedDefault = array( -1 => 0, 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0,100 => 0,101 => 0);
$wgNonincludableNamespaces[] = 100;

$wgGroupPermissions['*']['readrbonly'] = false;
$wgGroupPermissions['sysop']['readrbonly'] = true;

$wgNamespaceProtection[ 100 ] = array( 'readrbonly' );

# group permissions
$wgGroupPermissions['*']['autocreateaccount'] = true;
$wgGroupPermissions['*']['createaccount']   = false;
$wgGroupPermissions['*']['read']            = true;
$wgGroupPermissions['*']['edit']            = false;

# Exclude user group page views from counting.
$wgGroupPermissions['sysop']['hitcounter-exempt'] = true;

# When set to true, it adds the PageId to the special page "PopularPages". The default value is false.
$wgEnableAddPageId = false;

# When set to true, it adds the TextLength to the special page "PopularPages". The default value is false.
$wgEnableAddTextLength = true;

# debug logs
# $wgDebugDumpSql = true;
$wgShowExceptionDetails = true;
$wgShowDBErrorBacktrace = true;
$wgShowSQLErrors = true;
$wgDebugLogFile = "/dev/stderr";
EOH

        destination = "local/LocalSettings.php"
      }
    }

    service {
      name = "rbwiki-db"
      port = "db"

      check {
        name = "mariadb_probe"
        type = "tcp"
        interval = "10s"
        timeout = "2s"
      }
    }

    task "rbwiki-db" {
      driver = "docker"

      constraint {
        attribute = "${attr.unique.hostname}"
        value     = "glados"
      }

      config {
        image = "mariadb"
        ports = ["db"]

        volumes = [
          "/opt/mediawiki-db:/var/lib/mysql",
          "/oldstorage/wiki_backups:/wiki-backups/backup",
          "local/conf.cnf:/etc/mysql/mariadb.conf.d/50-server.cnf",
        ]
      }

      template {
        data = <<EOH
[mysqld]
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
innodb_file_per_table = 1

bind-address = 0.0.0.0
# Logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1
EOH

        destination = "local/conf.cnf"
      }

      resources {
          cpu    = 800
          memory = 1200
        }

      template {
        data = <<EOH
MYSQL_DATABASE={{ key "mediawiki/db/name" }}
MYSQL_USER={{ key "mediawiki/db/username" }}
MYSQL_PASSWORD={{ key "mediawiki/db/password" }}
MYSQL_RANDOM_ROOT_PASSWORD=yes
EOH

        destination = "local/.env"
        env = true
      }
    }
  }
}
