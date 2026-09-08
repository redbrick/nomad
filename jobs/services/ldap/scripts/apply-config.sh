#!/bin/bash
set -e

log() {
  echo "[Bootstrap Ldifs] $*"
}

apply_ldif() {
    local file="$1"
    module_name="${file:3:-5}"

    if slapcat -F /opt/bitnami/openldap/etc/slapd.d -b cn=config | grep -q $module_name
    then
        echo "$module_name overlay is already configured."
    else
        slapadd -F /opt/bitnami/openldap/etc/slapd.d -b cn=config -l ./"$file" || {
            echo "NOTICE: slapadd failed to load $module_name overlay. Check the cn=module{N} with \"slapcat -F /opt/bitnami/openldap/etc/slapd.d -b cn=config |grep 'cn=module'\""
            exit 1
        }
    fi

  log "applied: $file"
}

log "starting LDIF bootstrap"

shopt -s nullglob

for f in ./*.ldif; do
  apply_ldif "$f"
done



