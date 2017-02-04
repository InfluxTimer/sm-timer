<?php
require_once( 'inc/infdef.php' ); // Must always be included first.
require_once( INF_INC_DIR . '/infdb.php' );
require_once( INF_INC_DIR . '/infcommon.php' );
require_once( INF_INC_DIR . '/inftable.php' );
require_once( INF_INC_DIR . '/infsteamquery.php' );


$inf = new InfDb();


$mapname = isset( $_GET['m'] ) ? $_GET['m'] : '';

$mapnameup = mb_strtoupper( $mapname );

$mapid = $inf->getMapByName( $mapname );

if ( $mapid === false )
{
	InfCommon::redirect();
}


$inf_title = $mapname;

include_once( 'pages/header.php' );
include_once( 'pages/sitehead.php' );


$rec_drawc = 5;



$ret = $inf->getRecentRecords( -1, $mapid, -1, -1, -1, $rec_drawc + 1 );

if ( $ret )
{
	$table = new InfRecordTable( 'RECENT RECORDS - ' . $mapnameup, 'recentmaprecords', 'rectable-full-table' );
	$table->addColumn( 'PLAYER', function( $row ) {
		return '<a href="user.php?u='. InfCommon::steamId3To64( $row['steamid'] ) . '">' . $row['name'] . '</a>';
	} );
	$table->addColumn( 'STYLE', function( $row ) {
		global $inf;
		return $inf->getFullStyleName( $row['mode'], $row['style'] );
	} );
	$table->addColumn( 'RUN', function( $row ){return InfCommon::getRunName( $row['runid'] );} );
	$table->addColumn( 'TIME', function( $row ){return InfCommon::formatSeconds($row['rectime']);} );
	$table->addColumn( 'DATE', function( $row ){return InfCommon::formatDate($row['recdate']);} );
	$table->setDrawNav( count( $ret ) > $rec_drawc ? true : false, array( 'player', 'style', 'run', 'time', 'date' ) );
	$table->output( $ret );
}


$ret = $inf->getRecentSRs( -1, $mapid, -1, -1, -1, $rec_drawc + 1 );

if ( $ret )
{
	$table = new InfRecordTable( 'TOP RECORDS - ' . $mapnameup, 'recentmaptoprecords', 'rectable-full-table' );
	$table->addColumn( 'PLAYER', function( $row ) {
		return '<a href="user.php?u='. InfCommon::steamId3To64( $row['steamid'] ) . '">' . $row['name'] . '</a>';
	} );
	$table->addColumn( 'STYLE', function( $row ) {
		global $inf;
		return $inf->getFullStyleName( $row['mode'], $row['style'] );
	} );
	$table->addColumn( 'RUN', function( $row ){return InfCommon::getRunName( $row['runid'] );} );
	$table->addColumn( 'TIME', function( $row ){return InfCommon::formatSeconds($row['rectime']);} );
	$table->addColumn( 'DATE', function( $row ){return InfCommon::formatDate($row['recdate']);} );
	$table->setDrawNav( count( $ret ) > $rec_drawc ? true : false, array( 'player', 'style', 'run', 'time', 'date' ) );
	$table->output( $ret );
}

include_once( 'pages/footer.php' );
?>