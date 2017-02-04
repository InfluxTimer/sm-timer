<?php
require_once( 'inc/infdef.php' ); // Must always be included first.
require_once( INF_INC_DIR . '/infdb.php' );
require_once( INF_INC_DIR . '/infcommon.php' );
require_once( INF_INC_DIR . '/inftable.php' );
require_once( INF_INC_DIR . '/infsteamquery.php' );


$inf = new InfDb();


$steam64 = isset( $_GET['u'] ) ? $_GET['u'] : '';

$ply = $inf->getUserInfoBySteam( InfCommon::steamId64To3( $steam64 ) );
if ( !$ply )
{
	InfCommon::redirect();
}



if ( InfCommon::hasSteamAPIKey() )
{
	$sinfo = $inf->getUserSteamInfo( $ply['uid'] );
	
	$querysteam = true;
	
	if ( $sinfo )
	{
		$lastquery = isset( $sinfo['steam_lastquery'] ) ? strtotime( $sinfo['steam_lastquery'] ) : false;
		
		if ( $lastquery !== false && (strtotime( $inf->getDate() ) - $lastquery) < 86400 )
		{
			$querysteam = false;
		}
	}
	
	if ( $querysteam )
	{
		$steamquery = new InfSteamQuery( function( $row ) {
			global $ply, $inf;
			global $prof_avatar, $prof_name;
			
			$prof_avatar = $row['avatarfull'];
			$prof_name = $row['personaname'];
			
			$inf->updateUserInfo( $ply['uid'], $prof_name, $row['avatar'], $prof_avatar );
		} );
		$steamquery->querySummaries( $steam64 );
		
		$GLOBALS['inf_devfooter'] = 'Queried Steam.';
	}
	else
	{
		$prof_avatar = $sinfo['steam_avatarfull'];
	}
}

if ( !isset( $prof_name ) )
{
	$prof_name = $ply['name'];
}

if ( !isset( $prof_url ) )
{
	$prof_url = 'http://steamcommunity.com/profiles/' . $steam64;
}

$prof_name = htmlspecialchars( $prof_name );
$prof_nameup = mb_strtoupper( $prof_name );



$inf_title = $prof_name;
$inf_header = '<link rel="stylesheet" type="text/css" href="css/user.css">';

include_once( 'pages/header.php' );
include_once( 'pages/sitehead.php' );
?>
<div class="usercont">
<?php
if ( isset( $prof_avatar ) )
{
	echo '<div class="user-avatar-container"><a href="' . $prof_url . '" target="_blank"><img class="user-avatar user-avatar-online" src="' . $prof_avatar . '"/></a></div>';
}

$table = new InfInfoTable( 'USER INFO' );
$table->addColumn( 'NAME', function( $row ) {
	global $prof_name;
	return $prof_name;
} );
$table->addColumn( 'STEAM ID', function( $row ){return $row['steamid'];} );
$table->addColumn( 'JOINED', function( $row ){return InfCommon::formatDate($row['joindate']);} );
$table->output( $ply );
?>
</div>
<?php
$rec_drawc = 5;
$rec_count = $inf->getRecordsCount( $ply['uid'] );


$ret = $inf->getRecentRecords( $ply['uid'], -1, -1, -1, -1, $rec_drawc );

if ( $ret )
{
	$table = new InfRecordTable( 'RECENT RECORDS - ' . $prof_nameup, 'recentrecords', 'rectable-full-table' );
	$table->addColumn( 'MAP', function( $row ) {
		return '<a href="map.php?m='. $row['mapname'] . '">' . $row['mapname'] . '</a>';
	} );
	$table->addColumn( 'STYLE', function( $row ) {
		global $inf;
		return $inf->getFullStyleName( $row['mode'], $row['style'] );
	} );
	$table->addColumn( 'RUN', function( $row ){return InfCommon::getRunName( $row['runid'] );} );
	$table->addColumn( 'TIME', function( $row ){return InfCommon::formatSeconds($row['rectime']);} );
	$table->addColumn( 'DATE', function( $row ){return InfCommon::formatDate($row['recdate']);} );
	$table->setDrawNav( $rec_count >= $rec_drawc ? true : false, array( 'map', 'style', 'run', 'time', 'date' ) );
	$table->output( $ret );
}


$ret = $inf->getRecentSRs( $ply['uid'] );

if ( $ret )
{
	$table = new InfRecordTable( 'TOP RECORDS - ' . $prof_nameup, 'recenttoprecords', 'rectable-full-table' );
	$table->addColumn( 'MAP', function( $row ) {
		return '<a href="map.php?m='. $row['mapname'] . '">' . $row['mapname'] . '</a>';
	} );
	$table->addColumn( 'STYLE', function( $row ) {
		global $inf;
		return $inf->getFullStyleName( $row['mode'], $row['style'] );
	} );
	$table->addColumn( 'RUN', function( $row ){return InfCommon::getRunName( $row['runid'] );} );
	$table->addColumn( 'TIME', function( $row ){return InfCommon::formatSeconds($row['rectime']);} );
	$table->addColumn( 'DATE', function( $row ){return InfCommon::formatDate($row['recdate']);} );
	$table->setDrawNav( false, array( 'map', 'style', 'run', 'time', 'date' ) );
	$table->output( $ret );
}

include_once( 'pages/footer.php' );
?>