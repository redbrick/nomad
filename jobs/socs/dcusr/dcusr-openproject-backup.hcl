job "dcusr-openproject-backup" {
  datacenters = ["aperture"]
  type        = "batch"

  periodic {
    crons            = ["0 */3 * * * *"]
    prohibit_overlap = true
  }

  group "db-backup" {
    task "openproject-backup" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["local/script.sh"]
      }

      template {
        destination = "local/script.sh"
        data        = <<EOH
#!/bin/bash
set -e

BACKUP_BASE="/storage/backups/nomad/openproject/dcusr"
mkdir -p "${BACKUP_BASE}"

job_name=$(echo ${NOMAD_JOB_NAME} | cut -d "/" -f 1)
timestamp="$(TZ=Europe/Dublin date '+%Y-%m-%d_%H-%M-%S')"
outfile="${BACKUP_BASE}/openproject-${timestamp}.zip"

if [ -z "${OPENPROJECT_DOMAIN}" ] || [ -z "${OPENPROJECT_API_KEY}" ] || [ -z "${OPENPROJECT_BACKUP_TOKEN}" ]; then
  echo "Missing required Consul keys (OPENPROJECT_DOMAIN / OPENPROJECT_API_KEY / OPENPROJECT_BACKUP_TOKEN)."
  exit 1
fi

curl -s -X POST -u "apikey:${OPENPROJECT_API_KEY}" \
  "https://${OPENPROJECT_DOMAIN}/api/v3/backups" \
  -H 'content-type: application/json' \
  --data-raw "{\"backupToken\":\"${OPENPROJECT_BACKUP_TOKEN}\",\"attachments\":true}" \
  > /tmp/op_backup_response.json || {
    echo "Failed to POST backup creation"
    exit 1
  }

status_path="$(jq -r ._links.job_status.href < /tmp/op_backup_response.json 2>/dev/null || true)"
if [ -z "${status_path}" ] || [ "${status_path}" = "null" ]; then
  echo "Could not obtain job_status link from API response"
  cat /tmp/op_backup_response.json || true
  exit 1
fi

status_url="https://${OPENPROJECT_DOMAIN}${status_path}"

while true; do
  curl -s -u "apikey:${OPENPROJECT_API_KEY}" "${status_url}" > /tmp/op_status.json || {
    echo "Failed to fetch status from ${status_url}"
    sleep 5
    continue
  }

  status="$(jq -r .status < /tmp/op_status.json 2>/dev/null || true)"
  if [ "${status}" = "success" ]; then
    echo "Backup ready for download"
    break
  fi

  if [ "${status}" = "failed" ] || [ "${status}" = "error" ]; then
    echo "Backup job failed (status=${status})"
    cat /tmp/op_status.json || true
    if [ -n "${DISCORD_WEBHOOK}" ]; then
      curl -s -H "Content-Type: application/json" -d \
        "{\"content\": \"<@&585512338728419341> \`OpenProject\` backup for **${job_name}** has **FAILED**. Status: ${status}. Date: $(TZ=Europe/Dublin date)\"}" \
        "${DISCORD_WEBHOOK}" || true
    fi
    exit 2
  fi

  echo "waiting for backup generation (current status=${status})"
  sleep 5
done

download_path="$(jq -r .payload.download < /tmp/op_status.json 2>/dev/null || true)"
if [ -z "${download_path}" ] || [ "${download_path}" = "null" ]; then
  echo "No download path found in status payload"
  exit 1
fi

download_url="https://${OPENPROJECT_DOMAIN}${download_path}"

curl -s -u "apikey:${OPENPROJECT_API_KEY}" -L "${download_url}" -o "${outfile}" || {
  echo "Failed to download backup to ${outfile}"
  [ -f "${outfile}" ] && rm -f "${outfile}"
  exit 1
}

if [ -s "${outfile}" ]; then
  echo "Backup successful: ${outfile}"
else
  echo "Downloaded file is empty or missing: ${outfile}"
  rm -f "${outfile}" || true
  if [ -n "${DISCORD_WEBHOOK}" ]; then
    curl -s -H "Content-Type: application/json" -d \
      "{\"content\": \"<@&585512338728419341> \`OpenProject\` backup for **${job_name}** has just **FAILED** (empty file). File: ${outfile} Date: $(TZ=Europe/Dublin date)\"}" \
      "${DISCORD_WEBHOOK}" || true
  fi
  exit 1
fi

find "${BACKUP_BASE}" -name 'openproject-*.zip' -ctime +3 -exec rm {} \; || true

exit 0
EOH
      }

      template {
        destination = "local/consul_env"
        env         = true
        data        = <<EOH
OPENPROJECT_DOMAIN={{ key "dcusr/openproject/domain" }}
OPENPROJECT_API_KEY={{ key "dcusr/openproject/api/key" }}
OPENPROJECT_BACKUP_TOKEN={{ key "dcusr/openproject/backup/token" }}
DISCORD_WEBHOOK={{ key "dcusr/postgres/webhook/discord" }}
EOH
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
