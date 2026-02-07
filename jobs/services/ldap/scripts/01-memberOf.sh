#!/bin/bash
# Script to enable memberOf overlay in OpenLDAP
set -e

# Note: cn=module{1},cn=config assumes that the module will be loaded as the second module. cn=module{0} being the first.
# Additionally, olcDatabase={2}mdb assumes that the database is the second one configured in OpenLDAP. Adjust as necessary.

# Create a temporary LDIF file
# ensure cn=module{N},cn=config and cn: module{N} match eachother and do not conflict with existing modules. Run `slapcat -F /opt/bitnami/openldap/etc/slapd.d -b cn=config | grep 'cn=module'` to check existing modules.
cat > /tmp/memberof-overlay.ldif << 'EOF'
dn: cn=module{3},cn=config
objectClass: olcModuleList
cn: module{3}
olcModuleLoad: memberof

dn: olcOverlay=memberof,olcDatabase={1}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcMemberOf
olcOverlay: memberof
olcMemberOfDangling: ignore
olcMemberOfRefInt: TRUE
olcMemberOfGroupOC: groupOfNames
olcMemberOfMemberAD: member
olcMemberOfMemberOfAD: memberOf
EOF

# Apply the LDIF to enable memberOf overlay
echo "Enabling memberOf overlay in OpenLDAP configuration..."
echo "Loading memberOf overlay with slapadd..."

if slapcat -F /opt/bitnami/openldap/etc/slapd.d -b cn=config | grep -q memberof
then
    echo "MemberOf overlay is already configured."
    exit 0
else
    slapadd -F /opt/bitnami/openldap/etc/slapd.d -b cn=config -l /tmp/memberof-overlay.ldif || {
        echo "NOTICE: slapadd failed to load memberOf overlay. Check the cn=module{N} with \"slapcat -F /opt/bitnami/openldap/etc/slapd.d -b cn=config |grep 'cn=module'\""
        exit 1
    }
fi

echo "MemberOf overlay has been configured."

