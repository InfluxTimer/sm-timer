<?php
define( '_INF', '' );

define( 'INF_INC_DIR', __DIR__ );
define( 'INF_PAGE_DIR', __DIR__ . '/../pages' );


require_once( INF_INC_DIR . '/../config.php' );


ini_set( 'display_errors', ( INF_DEBUG || defined( 'INF_INSTALL' ) ) ? '1' : '0' );


if ( !defined( 'INF_INSTALL' ) && file_exists( INF_INC_DIR . '/../install' ) )
{
	$dir = rtrim( $_SERVER['REQUEST_URI'], '/\\' );
	$dir = preg_replace( "~^[/\\\]$~", '', dirname( $dir ) );
	exit( "Please go to {$_SERVER['HTTP_HOST']}{$dir}/install. If you've already done this, delete the install directory." );
}
?>