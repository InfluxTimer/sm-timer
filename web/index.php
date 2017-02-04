<?php
require_once( 'inc/infdef.php' ); // Must always be included first.
require_once( INF_INC_DIR . '/infdb.php' );
require_once( INF_INC_DIR . '/infcommon.php' );
require_once( INF_INC_DIR . '/inftable.php' );


$inf = new InfDb();


include_once( 'pages/header.php' );
include_once( 'pages/sitehead.php' );


// Amount of rows to draw.
$rec_drawc = 6;


// Recent records.
$ret = $inf->getRecentRecords( -1, -1, -1, -1, -1, $rec_drawc + 1 );


$table = new InfRecordTable( 'RECENT RECORDS', 'recentrecords', 'rectable-full-table', $rec_drawc );
$table->addColumn( 'MAP', function( $row ) {
	return '<a href="map.php?m='. $row['mapname'] . '">' . $row['mapname'] . '</a>';
} );
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
$table->setDrawNav( count( $ret ) > $rec_drawc ? true : false, array( 'map', 'player', 'style', 'run', 'time', 'date' ) );
$table->output( $ret ? $ret : 'No records were found! :(' );



// Recent server records.
$ret = $inf->getRecentSRs( -1, -1, -1, -1, -1, $rec_drawc + 1 );


$table = new InfRecordTable( 'RECENT TOP RECORDS', 'recenttoprecords', 'rectable-full-table', $rec_drawc );
$table->addColumn( 'MAP', function( $row ) {
	return '<a href="map.php?m='. $row['mapname'] . '">' . $row['mapname'] . '</a>';
} );
$table->addColumn( 'PLAYER', function( $row ) {
	return '<a href="user.php?u='. InfCommon::steamId3To64( $row['steamid'] ) . '">' . htmlspecialchars( $row['name'] ) . '</a>';
} );
$table->addColumn( 'STYLE', function( $row ) {
	global $inf;
	return $inf->getFullStyleName( $row['mode'], $row['style'] );
} );
$table->addColumn( 'RUN', function( $row ){return InfCommon::getRunName( $row['runid'] );} );
$table->addColumn( 'TIME', function( $row ){return InfCommon::formatSeconds($row['rectime']);} );
$table->addColumn( 'DATE', function( $row ){return InfCommon::formatDate($row['recdate']);} );
$table->setDrawNav( count( $ret ) > $rec_drawc ? true : false, array( 'map', 'player', 'style', 'run', 'time', 'date' ) );
$table->output( $ret ? $ret : 'No records were found! :(' );



$rec_drawc = 5;

// Top players
$ret = $inf->getTopPlayers( -1, -1, -1, -1, $rec_drawc + 1 );

if ( $ret )
{
	$table = new InfRecordTable( 'TOP PLAYERS', 'topplayers', '', $rec_drawc );
	$table->setDrawRowFunc( function( $row ) {
		return ( $row['numrecs'] != 0 ) ? true : false;
	} );
	$table->addColumn( 'PLAYER', function( $row ) {
		return '<a href="user.php?u='. InfCommon::steamId3To64( $row['steamid'] ) . '">' . htmlspecialchars( $row['name'] ) . '</a>';
	} );
	$table->addColumn( '# - TOP RECORDS', function( $row ){return $row['numrecs'];} );
	$table->setDrawNav( count( $ret ) > $rec_drawc ? true : false, array( 'player', 'topnum' ) );
	$table->output( $ret ? $ret : 'No records were found! :(' );
}


include_once( 'pages/footer.php' );
?>