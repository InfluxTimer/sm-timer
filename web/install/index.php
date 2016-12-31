<?php
define( 'INF_INSTALL', true );

require_once( '../inc/infdef.php' );
require_once( INF_INC_DIR . '/infdb.php' );


$inf = new InfDb();

$pdo = $inf->getDB();

if ( $pdo->exec(	"CREATE TABLE IF NOT EXISTS ".INF_TABLE_USERS_STEAMCACHE." (" .
					"uid INTEGER NOT NULL PRIMARY KEY," .
					"steam_avatar VARCHAR(256) NOT NULL," .
					"steam_avatarfull VARCHAR(256) NOT NULL," .
					"steam_lastquery TIMESTAMP NOT NULL)" ) === false )
{
	exit( "Unable to create tables! Error: {$pdo->errorInfo()[2]}" );
}


echo 'Installation was successful! Proceed by deleting this directory.';
?>