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
$wgDBTableOptions = "ENGINE=InnoDB, DEFAULT CHARSET=utf8mb4";

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

$wgDefaultSkin = "vector";
$wgDefaultMobileSkin = 'vector-2022';

# Enabled skins.
wfLoadSkin( 'Vector' );
wfLoadSkin( 'Citizen' );
wfLoadSkin( 'Timeless' );
wfLoadSkin( 'MinervaNeue' );
wfLoadSkin( 'Medik' );

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
$wgPlausibleDomainKey = "{{ env "NOMAD_META_domain" }}";
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
