<?php
if ( !defined( '_INF' ) ) exit( 'Nice try, buddy.' );



// Set to false to disable error displayiung.
// ./install/index.php will always have error displaying on.
define( 'INF_DEBUG', true );


// Fill me.
define( 'INF_HOST', '127.0.0.1' );
define( 'INF_DBNAME', 'influxdatabasename' );
define( 'INF_USER', '' );
define( 'INF_PASS', '' );
define( 'INF_PORT', '3306' );


// Use persistent MySQL connection.
// Set to false if you are capping your maximum connections.
define( 'INF_SQL_PERSISTENT', false );


// In order to retrieve user's Steam avatar and name.
// Leave empty if not interested.
define( 'INF_STEAMWEBAPIKEY', '' );
// How much do we wait before querying Steam again per user.
define( 'INF_USERQUERYLIMIT_SEC', 86400 );


// Regular expression of allowed maps to be shown.
define( 'INF_ALLOWED_MAPS_REGEX', '^(bhop\_|surf\_|kz\_)' );


// Display minor developer info on the page.
define( 'INF_DEV', false );
?>