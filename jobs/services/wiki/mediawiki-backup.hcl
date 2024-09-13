job "mediawiki-backup" {
  datacenters = ["aperture"]
  type        = "batch"

  periodic {
    crons            = ["0 */3 * * * *"]
    prohibit_overlap = true
  }

  group "db-backup" {
    task "mysql-backup" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["local/mysql-backup.sh"]
      }

      template {
        data = <<EOH
#!/bin/bash

file=/storage/backups/nomad/wiki/mysql/rbwiki-mysql-$(date +%Y-%m-%d_%H-%M-%S).sql

mkdir -p /storage/backups/nomad/wiki/mysql

alloc_id=$(nomad job status mediawiki | grep running | tail -n 1 | cut -d " " -f 1)

job_name=$(echo ${NOMAD_JOB_NAME} | cut -d "/" -f 1)

nomad alloc exec -task rbwiki-db $alloc_id mariadb-dump -u {{ key "mediawiki/db/username" }} -p'{{ key "mediawiki/db/password"}}' {{ key "mediawiki/db/name" }} > "${file}"

find /storage/backups/nomad/wiki/mysql/rbwiki-mysql* -ctime +3 -exec rm {} \; || true

if [ -s "$file" ]; then # check if file exists and is not empty
  echo "Backup successful"
  exit 0
else
  rm $file
  curl -H "Content-Type: application/json" -d \
  '{"content": "<@&585512338728419341> `MySQL` backup for **'"${job_name}"'** has just **FAILED**\nFile name: `'"$file"'`\nDate: `'"$(TZ=Europe/Dublin date)"'`\nTurn off this script with `nomad job stop '"${job_name}"'` \n\n## Remember to restart this backup job when fixed!!!"}' \
  {{ key "mysql/webhook/discord" }}
fi
EOH
        destination = "local/mysql-backup.sh"
      }
    }
  }
  group "xml-dump" {
    task "xml-dump" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["local/xml-dump.sh"]
      }

      template {
        data = <<EOH
#!/bin/bash

file=/storage/backups/nomad/wiki/xml/rbwiki-dump-$(date +%Y-%m-%d_%H-%M-%S).xml

mkdir -p /storage/backups/nomad/wiki/xml

alloc_id=$(nomad job status mediawiki | grep running | tail -n 1 | cut -d " " -f 1)

job_name=$(echo ${NOMAD_JOB_NAME} | cut -d "/" -f 1)

nomad alloc exec -task rbwiki-php $alloc_id /usr/local/bin/php /var/www/html/maintenance/dumpBackup.php --full --include-files --uploads > "${file}"

find /storage/backups/nomad/wiki/xml/rbwiki-dump* -ctime +3 -exec rm {} \; || true

if [ -n "$(find ${file} -prune -size +100000000c)" ]; then # check if file exists and is not empty
  echo "Backup successful"
  exit 0
else
  rm $file
  curl -H "Content-Type: application/json" -d \
  '{"content": "<@&585512338728419341> `dumpBackup.php` backup for **'"${job_name}"'** has just **FAILED**\nFile name: `'"$file"'`\nDate: `'"$(TZ=Europe/Dublin date)"'`\nTurn off this script with `nomad job stop '"${job_name}"'` \n\n## Remember to restart this backup job when fixed!!!"}' \
  {{ key "mysql/webhook/discord" }}
fi
EOH
        destination = "local/xml-dump.sh"
      }
    }
  }
}

