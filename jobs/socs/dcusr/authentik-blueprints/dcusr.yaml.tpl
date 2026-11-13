# authentik configuration for auth.solarracing.ie, applied by the authentik
# worker on startup (rendered by Nomad into /blueprints/dcusr/dcusr.yaml).
#
# This is a Nomad template, not a plain blueprint: the Consul "key" lookups are
# filled from Consul when the job starts. Group/role names and OAuth client
# credentials live in Consul; everything else is here.
#
# Covers: groups, roles, application access bindings, OAuth providers and apps,
# scope mappings, the recovery flow, brand, notification rules, and the built-in
# flows/stages that were customised. Built-in objects left at their defaults are
# not listed (authentik recreates them). Users, MFA devices and tokens are data,
# not config: restore those from the dcusr-authentik-db-backup dumps.
#
# Editing: change the object here, redeploy the job. The worker re-applies the
# blueprint whenever the rendered file changes. Objects defined here are owned
# by this file, so UI edits to them are overwritten on the next apply.
version: 1
metadata:
  name: dcusr - authentik configuration
entries:
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: system/bootstrap.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: system/providers-oauth2.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: system/providers-proxy.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-default-authentication-flow.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-default-invalidation-flow.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-default-provider-authorization-explicit-consent.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-default-provider-authorization-implicit-consent.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-default-provider-invalidation.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-default-source-authentication.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-default-source-enrollment.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-default-source-pre-authentication.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-default-user-settings-flow.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-password-change.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-default-authenticator-totp-setup.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-default-authenticator-static-setup.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/flow-default-authenticator-webauthn-setup.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/events-default.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/default-brand.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/rbac-role-read-only.yaml
    required: false
- model: authentik_blueprints.metaapplyblueprint
  attrs:
    identifiers:
      path: default/rbac-role-agents.yaml
    required: false
- model: authentik_rbac.role
  identifiers:
    name: {{ key "socs/dcusr/authentik/roles/default" | toJSON }}
  attrs: {}
  id: e000
- model: authentik_rbac.role
  identifiers:
    name: {{ key "socs/dcusr/authentik/roles/users-only" | toJSON }}
  attrs: {}
  id: e001
- model: authentik_core.group
  identifiers:
    name: {{ key "socs/dcusr/authentik/groups/business" | toJSON }}
  attrs:
    attributes: {}
    is_superuser: false
    parents: []
    roles: []
  id: e002
- model: authentik_core.group
  identifiers:
    name: {{ key "socs/dcusr/authentik/groups/website-admin" | toJSON }}
  attrs:
    attributes: {}
    is_superuser: false
    parents: []
    roles: []
  id: e003
- model: authentik_core.group
  identifiers:
    name: {{ key "socs/dcusr/authentik/groups/website-editor" | toJSON }}
  attrs:
    attributes: {}
    is_superuser: false
    parents: []
    roles: []
  id: e004
- model: authentik_core.group
  identifiers:
    name: {{ key "socs/dcusr/authentik/groups/website-viewer" | toJSON }}
  attrs:
    attributes: {}
    is_superuser: false
    parents: []
    roles: []
  id: e005
- model: authentik_core.group
  identifiers:
    name: {{ key "socs/dcusr/authentik/groups/software" | toJSON }}
  attrs:
    attributes: {}
    is_superuser: false
    parents: []
    roles: []
  id: e006
- model: authentik_core.group
  identifiers:
    name: {{ key "socs/dcusr/authentik/groups/elec" | toJSON }}
  attrs:
    attributes: {}
    is_superuser: false
    parents: []
    roles: []
  id: e007
- model: authentik_core.group
  identifiers:
    name: {{ key "socs/dcusr/authentik/groups/mech" | toJSON }}
  attrs:
    attributes: {}
    is_superuser: false
    parents: []
    roles: []
  id: e008
- model: authentik_core.group
  identifiers:
    name: {{ key "socs/dcusr/authentik/groups/marketing" | toJSON }}
  attrs:
    attributes: {}
    is_superuser: false
    parents: []
    roles: []
  id: e009
- model: authentik_core.group
  identifiers:
    name: {{ key "socs/dcusr/authentik/groups/view-users" | toJSON }}
  attrs:
    attributes: {}
    is_superuser: false
    parents: []
    roles:
    - !Find [authentik_rbac.role, [name, {{ key "socs/dcusr/authentik/roles/users-only" | toJSON }}]]
  id: e010
- model: authentik_core.group
  identifiers:
    name: {{ key "socs/dcusr/authentik/groups/drive-only" | toJSON }}
  attrs:
    attributes: {}
    is_superuser: false
    parents: []
    roles: []
  id: e011
- model: authentik_core.group
  identifiers:
    name: {{ key "socs/dcusr/authentik/groups/read-only" | toJSON }}
  attrs:
    attributes: {}
    is_superuser: false
    parents:
    - !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/business" | toJSON }}]]
    - !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/website-viewer" | toJSON }}]]
    - !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/software" | toJSON }}]]
    - !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/elec" | toJSON }}]]
    - !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/mech" | toJSON }}]]
    - !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/marketing" | toJSON }}]]
    roles: []
  id: e012
- model: authentik_policies_expression.expressionpolicy
  identifiers:
    name: default-recovery-skip-if-restored
  attrs:
    execution_logging: false
    expression: return bool(request.context.get('is_restored', True))
  id: e013
- model: authentik_stages_prompt.prompt
  identifiers:
    name: default-recovery-field-password
  attrs:
    field_key: password
    initial_value: ''
    initial_value_expression: false
    label: Password
    order: 0
    placeholder: Password
    placeholder_expression: false
    required: true
    sub_text: ''
    type: password
  id: e014
- model: authentik_stages_prompt.prompt
  identifiers:
    name: default-recovery-field-password-repeat
  attrs:
    field_key: password_repeat
    initial_value: ''
    initial_value_expression: false
    label: Password (repeat)
    order: 1
    placeholder: Password (repeat)
    placeholder_expression: false
    required: true
    sub_text: ''
    type: password
  id: e015
- model: authentik_stages_authenticator_validate.authenticatorvalidatestage
  identifiers:
    name: default-recovery-mfa
  attrs:
    configuration_stages: []
    device_classes:
    - static
    - totp
    - webauthn
    - duo
    - sms
    - email
    email_otp_throttling_factor: 1.0
    last_auth_threshold: seconds=0
    not_configured_action: skip
    sms_otp_throttling_factor: 1.0
    static_otp_throttling_factor: 1.0
    totp_otp_throttling_factor: 1.0
    webauthn_allowed_device_types: []
    webauthn_hints: []
    webauthn_user_verification: preferred
  id: e016
- model: authentik_stages_email.emailstage
  identifiers:
    name: default-recovery-email
  attrs:
    activate_user_on_success: true
    from_address: system@authentik.local
    host: localhost
    port: 25
    recovery_cache_timeout: minutes=5
    recovery_max_attempts: 5
    subject: authentik
    template: email/password_reset.html
    timeout: 10
    token_expiry: minutes=30
    use_global_settings: true
    use_ssl: false
    use_tls: false
    username: ''
  id: e017
- model: authentik_stages_identification.identificationstage
  identifiers:
    name: default-recovery-identification
  attrs:
    captcha_stage: null
    case_insensitive_matching: true
    enable_remember_me: false
    enrollment_flow: null
    password_stage: null
    passwordless_flow: null
    pretend_user_exists: true
    recovery_flow: null
    show_matched_user: true
    show_source_labels: false
    sources: []
    user_fields:
    - email
    - username
    webauthn_stage: null
  id: e018
- model: authentik_stages_prompt.promptstage
  identifiers:
    name: Change your password
  attrs:
    fields:
    - !Find [authentik_stages_prompt.prompt, [name, default-recovery-field-password]]
    - !Find [authentik_stages_prompt.prompt, [name, default-recovery-field-password-repeat]]
    validation_policies: []
  id: e019
- model: authentik_stages_user_login.userloginstage
  identifiers:
    name: default-recovery-user-login
  attrs:
    geoip_binding: no_binding
    network_binding: no_binding
    remember_device: days=30
    remember_me_offset: seconds=0
    session_duration: seconds=0
    terminate_other_sessions: false
  id: e020
- model: authentik_stages_user_write.userwritestage
  identifiers:
    name: default-recovery-user-write
  attrs:
    create_users_as_inactive: false
    create_users_group: null
    user_creation_mode: never_create
    user_path_template: ''
    user_type: external
  id: e021
- model: authentik_flows.flow
  identifiers:
    slug: default-recovery-flow
  attrs:
    authentication: require_unauthenticated
    background: ''
    compatibility_mode: false
    denied_action: message_continue
    designation: recovery
    layout: stacked
    name: Default recovery flow
    policy_engine_mode: any
    title: Reset your password
  id: e022
- model: authentik_flows.flowstagebinding
  identifiers:
    target: !Find [authentik_flows.flow, [slug, default-recovery-flow]]
    stage: !Find [authentik_stages_identification.identificationstage, [name, default-recovery-identification]]
    order: 10
  attrs:
    evaluate_on_plan: true
    invalid_response_action: retry
    policy_engine_mode: any
    re_evaluate_policies: true
  id: e023
- model: authentik_flows.flowstagebinding
  identifiers:
    target: !Find [authentik_flows.flow, [slug, default-recovery-flow]]
    stage: !Find [authentik_stages_email.emailstage, [name, default-recovery-email]]
    order: 20
  attrs:
    evaluate_on_plan: true
    invalid_response_action: retry
    policy_engine_mode: any
    re_evaluate_policies: true
  id: e024
- model: authentik_flows.flowstagebinding
  identifiers:
    target: !Find [authentik_flows.flow, [slug, default-recovery-flow]]
    stage: !Find [authentik_stages_authenticator_validate.authenticatorvalidatestage, [name, default-recovery-mfa]]
    order: 21
  attrs:
    evaluate_on_plan: true
    invalid_response_action: retry
    policy_engine_mode: any
    re_evaluate_policies: true
  id: e025
- model: authentik_flows.flowstagebinding
  identifiers:
    target: !Find [authentik_flows.flow, [slug, default-recovery-flow]]
    stage: !Find [authentik_stages_prompt.promptstage, [name, Change your password]]
    order: 30
  attrs:
    evaluate_on_plan: true
    invalid_response_action: retry
    policy_engine_mode: any
    re_evaluate_policies: false
  id: e026
- model: authentik_flows.flowstagebinding
  identifiers:
    target: !Find [authentik_flows.flow, [slug, default-recovery-flow]]
    stage: !Find [authentik_stages_user_write.userwritestage, [name, default-recovery-user-write]]
    order: 40
  attrs:
    evaluate_on_plan: true
    invalid_response_action: retry
    policy_engine_mode: any
    re_evaluate_policies: false
  id: e027
- model: authentik_flows.flowstagebinding
  identifiers:
    target: !Find [authentik_flows.flow, [slug, default-recovery-flow]]
    stage: !Find [authentik_stages_user_login.userloginstage, [name, default-recovery-user-login]]
    order: 100
  attrs:
    evaluate_on_plan: true
    invalid_response_action: retry
    policy_engine_mode: any
    re_evaluate_policies: false
  id: e028
- model: authentik_providers_oauth2.scopemapping
  identifiers:
    name: OpenProject Scope Mapping
  attrs:
    description: ''
    expression: |-
      name = request.user.name or request.user.username
      first_name, _, last_name = name.rpartition(" ")

      group_map = {
          {{ key "socs/dcusr/authentik/groups/business" | toJSON }}: "Business & Marketing",
          {{ key "socs/dcusr/authentik/groups/marketing" | toJSON }}: "Business & Marketing",
          {{ key "socs/dcusr/authentik/groups/elec" | toJSON }}: "Software & Electrical",
          {{ key "socs/dcusr/authentik/groups/software" | toJSON }}: "Software & Electrical",
          {{ key "socs/dcusr/authentik/groups/mech" | toJSON }}: "Mechanical & Aero",
      }

      op_groups = {
          group_map[g.name] for g in request.user.groups.all() if g.name in group_map
      }

      return {
          "name": name,
          "given_name": first_name or name,
          "family_name": last_name or name,
          "preferred_username": request.user.username,
          "nickname": request.user.username,
          "groups": list(op_groups),
          "first_name": first_name or name,
          "last_name": last_name or name,
      }
    managed: null
    scope_name: profile
  id: e029
- model: authentik_providers_oauth2.scopemapping
  identifiers:
    name: groups
  attrs:
    description: ''
    expression: |-
      return {
          "groups": list(request.user.groups.values_list("name", flat=True))
      }
    managed: null
    scope_name: groups
  id: e030
- model: authentik_providers_oauth2.scopemapping
  state: absent
  identifiers:
    name: InvenTree groups
  id: e031
- model: authentik_providers_oauth2.scopemapping
  state: absent
  identifiers:
    name: InvenTree profile (split name)
  id: e032
- model: authentik_providers_oauth2.scopemapping
  identifiers:
    name: pitwall-acl
  attrs:
    description: ''
    expression: |-
      groups = [g.name for g in request.user.groups.all()]
      if {{ key "socs/dcusr/authentik/groups/software" | toJSON }} in groups:
          acl = [{"permission": "allow", "action": "all", "topic": "solarcar/#"}]
      else:
          acl = [
              {"permission": "allow", "action": "subscribe", "topic": "solarcar/#"},
              {"permission": "deny", "action": "publish", "topic": "#"},
          ]
      return {"groups": groups, "acl": acl}
    managed: null
    scope_name: groups
  id: e033
- model: authentik_providers_oauth2.oauth2provider
  identifiers:
    name: Seafile OAuth Provider
  attrs:
    access_code_validity: minutes=1
    access_token_validity: minutes=5
    authentication_flow: null
    authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
    client_id: {{ key "socs/dcusr/seafile/oauth/client/id" | toJSON }}
    client_secret: {{ key "socs/dcusr/seafile/oauth/client/secret" | toJSON }}
    client_type: confidential
    encryption_key: null
    grant_types:
    - authorization_code
    - implicit
    - hybrid
    - refresh_token
    - client_credentials
    - password
    - urn:ietf:params:oauth:grant-type:device_code
    include_claims_in_id_token: true
    invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
    issuer_mode: per_provider
    jwt_federation_providers: []
    jwt_federation_sources: []
    logout_method: backchannel
    logout_uri: ''
    property_mappings:
    - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-openid]]
    - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-email]]
    - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-profile]]
    redirect_uris:
    - matching_mode: strict
      redirect_uri_type: authorization
      url: https://drive.solarracing.ie/oauth/callback/
    refresh_token_threshold: hours=1
    refresh_token_validity: days=30
    signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]
    sub_mode: user_email
  id: e034
- model: authentik_providers_oauth2.oauth2provider
  identifiers:
    name: Provider for listmonk
  attrs:
    access_code_validity: minutes=1
    access_token_validity: minutes=5
    authentication_flow: null
    authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
    client_id: {{ key "socs/dcusr/authentik/providers/listmonk/client_id" | toJSON }}
    client_secret: {{ key "socs/dcusr/authentik/providers/listmonk/client_secret" | toJSON }}
    client_type: confidential
    encryption_key: null
    grant_types:
    - authorization_code
    - implicit
    - hybrid
    - refresh_token
    - client_credentials
    - password
    - urn:ietf:params:oauth:grant-type:device_code
    include_claims_in_id_token: true
    invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
    issuer_mode: per_provider
    jwt_federation_providers: []
    jwt_federation_sources: []
    logout_method: backchannel
    logout_uri: ''
    property_mappings:
    - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-openid]]
    - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-email]]
    - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-profile]]
    redirect_uris:
    - matching_mode: strict
      redirect_uri_type: authorization
      url: https://lists.solarracing.ie/auth/oidc
    refresh_token_threshold: hours=1
    refresh_token_validity: days=30
    signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]
    sub_mode: hashed_user_id
  id: e035
- model: authentik_providers_oauth2.oauth2provider
  state: absent
  identifiers:
    name: Provider for inventree
  id: e036
- model: authentik_providers_oauth2.oauth2provider
  identifiers:
    name: Provider for openproject
  attrs:
    access_code_validity: minutes=1
    access_token_validity: minutes=5
    authentication_flow: null
    authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
    client_id: {{ key "socs/dcusr/openproject/oidc/client_id" | toJSON }}
    client_secret: {{ key "socs/dcusr/openproject/oidc/client_secret" | toJSON }}
    client_type: confidential
    encryption_key: null
    grant_types:
    - authorization_code
    - implicit
    - hybrid
    - refresh_token
    - client_credentials
    - password
    - urn:ietf:params:oauth:grant-type:device_code
    include_claims_in_id_token: true
    invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
    issuer_mode: per_provider
    jwt_federation_providers: []
    jwt_federation_sources: []
    logout_method: backchannel
    logout_uri: ''
    property_mappings:
    - !Find [authentik_providers_oauth2.scopemapping, [name, OpenProject Scope Mapping]]
    - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-openid]]
    - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-email]]
    redirect_uris:
    - matching_mode: strict
      redirect_uri_type: authorization
      url: https://projects.solarracing.ie/auth/authentik/callback
    refresh_token_threshold: hours=1
    refresh_token_validity: days=30
    signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]
    sub_mode: user_email
  id: e037
- model: authentik_providers_oauth2.oauth2provider
  identifiers:
    name: website
  attrs:
    access_code_validity: minutes=1
    access_token_validity: minutes=5
    authentication_flow: null
    authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
    client_id: {{ key "socs/dcusr/website/oidc/client/id" | toJSON }}
    client_secret: {{ key "socs/dcusr/website/oidc/client/secret" | toJSON }}
    client_type: confidential
    encryption_key: null
    grant_types:
    - authorization_code
    - implicit
    - hybrid
    - refresh_token
    - client_credentials
    - password
    - urn:ietf:params:oauth:grant-type:device_code
    include_claims_in_id_token: true
    invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
    issuer_mode: per_provider
    jwt_federation_providers: []
    jwt_federation_sources: []
    logout_method: backchannel
    logout_uri: ''
    property_mappings:
    - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-openid]]
    - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-email]]
    - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-profile]]
    - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-offline_access]]
    redirect_uris:
    - matching_mode: strict
      redirect_uri_type: authorization
      url: https://solarracing.ie/api/auth/callback/authentik
    - matching_mode: strict
      redirect_uri_type: authorization
      url: http://localhost:3000/api/auth/callback/authentik
    - matching_mode: strict
      redirect_uri_type: authorization
      url: http://localhost:3100/api/auth/callback/authentik
    - matching_mode: strict
      redirect_uri_type: authorization
      url: https://temp.solarracing.ie/api/auth/callback/authentik
    refresh_token_threshold: hours=1
    refresh_token_validity: days=30
    signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]
    sub_mode: hashed_user_id
  id: e038
- model: authentik_core.application
  state: absent
  identifiers:
    slug: inventree
  id: e039
- model: authentik_core.application
  identifiers:
    slug: openproject
  attrs:
    backchannel_providers: []
    group: ''
    meta_description: Project Management Dashboard
    meta_hide: false
    meta_icon: https://www.openproject.org/assets/images/press/openproject-icon-white-transparent-1-e710edd7.png
    meta_launch_url: ''
    meta_publisher: OpenProject
    name: openproject
    open_in_new_tab: true
    policy_engine_mode: any
    provider: !Find [authentik_providers_oauth2.oauth2provider, [name, Provider for openproject]]
  id: e040
- model: authentik_core.application
  identifiers:
    slug: listmonk
  attrs:
    backchannel_providers: []
    group: ''
    meta_description: Lists application to manage newsletters & communication
    meta_hide: false
    meta_icon: https://listmonk.app/static/images/favicon.webp
    meta_launch_url: ''
    meta_publisher: Listmonk
    name: listmonk
    open_in_new_tab: true
    policy_engine_mode: any
    provider: !Find [authentik_providers_oauth2.oauth2provider, [name, Provider for listmonk]]
  id: e041
- model: authentik_core.application
  identifiers:
    slug: website
  attrs:
    backchannel_providers: []
    group: ''
    meta_description: Main DCU Solar Racing Website
    meta_hide: false
    meta_icon: https://cdn.redbrick.dcu.ie/solarracing/logo.png
    meta_launch_url: https://solarracing.ie/admin
    meta_publisher: DCUSR Website
    name: website
    open_in_new_tab: true
    policy_engine_mode: any
    provider: !Find [authentik_providers_oauth2.oauth2provider, [name, website]]
  id: e042
- model: authentik_core.application
  identifiers:
    slug: seafile
  attrs:
    backchannel_providers: []
    group: ''
    meta_description: DCUSR Raw Footage Drive
    meta_hide: false
    meta_icon: https://manual.seafile.com/latest/media/seafile-transparent-1024.png
    meta_launch_url: ''
    meta_publisher: Seafile
    name: Drive (Seafile)
    open_in_new_tab: true
    policy_engine_mode: any
    provider: !Find [authentik_providers_oauth2.oauth2provider, [name, Seafile OAuth Provider]]
  id: e043
# Link-only app (no provider). Launch URL holds the Plausible share key, so it
# lives in Consul, not here.
- model: authentik_core.application
  identifiers:
    slug: plausible
  attrs:
    backchannel_providers: []
    group: ''
    meta_description: solarracing.ie website analytics
    meta_hide: false
    meta_icon: https://plausible.io/assets/images/icon/apple-touch-icon.png
    meta_launch_url: {{ key "socs/dcusr/authentik/plausible/launch_url" | toJSON }}
    meta_publisher: Plausible
    name: Plausible (Website Analytics)
    open_in_new_tab: true
    policy_engine_mode: any
  id: e084
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e043'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/drive-only" | toJSON }}]]
    order: 7
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e044
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e023'
    policy: !Find [authentik_policies_expression.expressionpolicy, [name, default-recovery-skip-if-restored]]
    order: 0
  attrs:
    enabled: true
    failure_result: false
    group: null
    negate: false
    timeout: 30
  id: e046
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e043'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/software" | toJSON }}]]
    order: 0
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e047
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e043'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/business" | toJSON }}]]
    order: 1
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e048
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e043'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/elec" | toJSON }}]]
    order: 2
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e049
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e043'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/marketing" | toJSON }}]]
    order: 3
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e050
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e043'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/mech" | toJSON }}]]
    order: 4
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e051
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e040'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/software" | toJSON }}]]
    order: 0
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e052
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e040'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/mech" | toJSON }}]]
    order: 1
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e053
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e040'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/marketing" | toJSON }}]]
    order: 2
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e054
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e040'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/elec" | toJSON }}]]
    order: 3
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e055
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e040'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/business" | toJSON }}]]
    order: 4
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e056
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e042'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/website-admin" | toJSON }}]]
    order: 0
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e057
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e042'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/website-editor" | toJSON }}]]
    order: 1
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e058
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e042'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/website-viewer" | toJSON }}]]
    order: 2
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e059
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e084'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/website-admin" | toJSON }}]]
    order: 0
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e085
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e041'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/business" | toJSON }}]]
    order: 1
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e060
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e041'
    group: !Find [authentik_core.group, [name, authentik Admins]]
    order: 0
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e061
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e043'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/read-only" | toJSON }}]]
    order: 5
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e066
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e041'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/read-only" | toJSON }}]]
    order: 2
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e068
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e040'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/read-only" | toJSON }}]]
    order: 5
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e069
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e042'
    group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/read-only" | toJSON }}]]
    order: 3
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e070
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e043'
    group: !Find [authentik_core.group, [name, authentik Admins]]
    order: 6
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e071
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e040'
    group: !Find [authentik_core.group, [name, authentik Admins]]
    order: 6
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e072
- model: authentik_policies.policybinding
  identifiers:
    target: !KeyOf 'e042'
    group: !Find [authentik_core.group, [name, authentik Admins]]
    order: 4
  attrs:
    enabled: true
    failure_result: false
    negate: false
    policy: null
    timeout: 30
  id: e073
- model: authentik_events.notificationrule
  identifiers:
    name: New User
  attrs:
    destination_event_user: true
    destination_group: !Find [authentik_core.group, [name, {{ key "socs/dcusr/authentik/groups/software" | toJSON }}]]
    severity: alert
    transports:
    - !Find [authentik_events.notificationtransport, [name, default-email-transport]]
  id: e074
- model: authentik_stages_authenticator_validate.authenticatorvalidatestage
  identifiers:
    name: default-authentication-mfa-validation
  attrs:
    configuration_stages:
    - !Find [authentik_stages_authenticator_totp.authenticatortotpstage, [name, default-authenticator-totp-setup]]
    - !Find [authentik_stages_authenticator_webauthn.authenticatorwebauthnstage, [name, default-authenticator-webauthn-setup]]
    device_classes:
    - static
    - totp
    - webauthn
    - duo
    - sms
    - email
    email_otp_throttling_factor: 1.0
    last_auth_threshold: seconds=0
    not_configured_action: configure
    sms_otp_throttling_factor: 1.0
    static_otp_throttling_factor: 1.0
    totp_otp_throttling_factor: 1.0
    webauthn_allowed_device_types: []
    webauthn_hints:
    - client-device
    - hybrid
    webauthn_user_verification: required
  id: e075
- model: authentik_stages_identification.identificationstage
  identifiers:
    name: default-authentication-identification
  attrs:
    captcha_stage: null
    case_insensitive_matching: true
    enable_remember_me: false
    enrollment_flow: null
    password_stage: null
    passwordless_flow: null
    pretend_user_exists: true
    recovery_flow: !Find [authentik_flows.flow, [slug, default-recovery-flow]]
    show_matched_user: true
    show_source_labels: false
    sources: []
    user_fields:
    - username
    - email
    webauthn_stage: null
  id: e076
- model: authentik_flows.flow
  identifiers:
    slug: default-source-authentication
  attrs:
    authentication: require_unauthenticated
    background: ''
    compatibility_mode: false
    denied_action: message_continue
    designation: authentication
    layout: stacked
    name: Welcome to DCUSR Auth!
    policy_engine_mode: any
    title: Welcome to DCUSR Auth!
  id: e077
- model: authentik_flows.flow
  identifiers:
    slug: default-source-enrollment
  attrs:
    authentication: none
    background: ''
    compatibility_mode: false
    denied_action: message_continue
    designation: enrollment
    layout: stacked
    name: Welcome to DCUSR Auth! Please select a username.
    policy_engine_mode: any
    title: Welcome to DCUSR Auth! Please select a username.
  id: e078
- model: authentik_brands.brand
  identifiers:
    default: true
  attrs:
    attributes: {}
    branding_custom_css: ''
    branding_default_flow_background: https://www.dcu.ie/sites/default/files/styles/user_defined/public/staff/2024-12/polaris-exterior-2th-dec-2024_38-resized.jpg.webp?h=5bd070cb&itok=yq2T9nB4
    branding_favicon: https://cdn.redbrick.dcu.ie/solarracing/2f515b7a-0024-4090-9732-16327d4d0d88.png
    branding_logo: https://cdn.redbrick.dcu.ie/solarracing/logo.png
    branding_map_tiles: ''
    branding_title: DCUSR Auth
    client_certificates: []
    default_application: null
    domain: auth.solarracing.ie
    flow_authentication: null
    flow_device_code: null
    flow_invalidation: null
    flow_lockdown: null
    flow_recovery: !Find [authentik_flows.flow, [slug, default-recovery-flow]]
    flow_request: null
    flow_unenrollment: null
    flow_user_settings: null
    flow_user_switch: null
    web_certificate: null
  id: e079
- model: authentik_events.notificationrule
  identifiers:
    name: default-notify-configuration-warning
  attrs:
    destination_event_user: false
    destination_group: !Find [authentik_core.group, [name, authentik Admins]]
    severity: warning
    transports:
    - !Find [authentik_events.notificationtransport, [name, default-email-transport]]
    - !Find [authentik_events.notificationtransport, [name, default-local-transport]]
  id: e080
- model: authentik_events.notificationrule
  identifiers:
    name: default-notify-configuration-error
  attrs:
    destination_event_user: true
    destination_group: !Find [authentik_core.group, [name, authentik Admins]]
    severity: alert
    transports:
    - !Find [authentik_events.notificationtransport, [name, default-email-transport]]
    - !Find [authentik_events.notificationtransport, [name, default-local-transport]]
  id: e081
- model: authentik_events.notificationrule
  identifiers:
    name: default-notify-exception
  attrs:
    destination_event_user: false
    destination_group: !Find [authentik_core.group, [name, authentik Admins]]
    severity: alert
    transports:
    - !Find [authentik_events.notificationtransport, [name, default-email-transport]]
    - !Find [authentik_events.notificationtransport, [name, default-local-transport]]
  id: e082
- model: authentik_events.notificationrule
  identifiers:
    name: default-notify-update
  attrs:
    destination_event_user: false
    destination_group: !Find [authentik_core.group, [name, authentik Admins]]
    severity: alert
    transports:
    - !Find [authentik_events.notificationtransport, [name, default-email-transport]]
    - !Find [authentik_events.notificationtransport, [name, default-local-transport]]
  id: e083
