<?php
require_once( 'inc/infdef.php' ); // Must always be included first.
require_once( INF_INC_DIR . '/infdb.php' );
require_once( INF_INC_DIR . '/infcommon.php' );
require_once( INF_INC_DIR . '/inftable.php' );
require_once( INF_INC_DIR . '/infsteamquery.php' );


$inf = new InfDb();


include_once( 'pages/header.php' );
include_once( 'pages/sitehead.php' );


if ( !isset( $_GET['q'] ) )
{
	InfCommon::redirect();
}


// Amount of rows to draw.
$rec_drawc = 10;

$plys = $inf->searchforPlayers( $_GET['q'], $rec_drawc + 1 );

$res = ( $plys && count( $plys ) > 0 ) ? true : false;


$table = new InfRecordTable( 'PLAYERS', 'searchplayers' );
$table->addColumn( 'NAME', function( $row ) {
	$name = '<p class="search-res-name">' . htmlspecialchars( $row['name'] ) . '</p>';
	
	$ulink = 'user.php?u=' . InfCommon::steamId3To64( $row['steamid'] );
	
	$avatar = ( isset( $row['_steam_avatar'] ) ? "<img class=\"search-res-img\" src=\"{$row['_steam_avatar']}\">" : '');
	
	return '<a href="' . $ulink . '">' . $avatar . $name . '</a>';
} );
$table->addColumn( 'JOINED', function( $row ) {return InfCommon::formatDate( $row['joindate'] );} );

$table->setDrawNav( count( $plys ) > $rec_drawc ? true : false, array( 'player', 'date' ) );


if ( $res && InfCommon::hasSteamAPIKey() )
{
	$steamids = array();
	
	$curdate = strtotime( $inf->getDate() );
	
	foreach ( $plys as &$ply )
	{
		$sinfo = $inf->getUserSteamInfo( $ply['uid'] );
		
		$querysteam = true;
		
		if ( $sinfo )
		{
			$lastquery = isset( $sinfo['steam_lastquery'] ) ? strtotime( $sinfo['steam_lastquery'] ) : false;
			
			if ( $lastquery !== false && ($curdate - $lastquery) < INF_USERQUERYLIMIT_SEC )
			{
				$querysteam = false;
			}
		}
		
		$steam64 = InfCommon::steamId3To64( $ply['steamid'] );
		
		if ( $querysteam )
		{
			$steamids[] = $steam64;
			
			$GLOBALS['inf_devfooter'] = 'Queried Steam.';
		}
		else
		{
			$ply['_steam_avatar'] = $sinfo['steam_avatar'];
		}
		
		$ply['_steam64'] = $steam64;
	}
	
	$steamquery = new InfSteamQuery( function( $row ) {
		global $plys, $inf;
		foreach ( $plys as &$ply )
		{
			if ( $row['steamid'] != $ply['_steam64'] ) continue;
			
			
			$prof_avatar = $row['avatar'];
			$prof_name = $row['personaname'];
			
			
			$ply['_steam_avatar'] = $prof_avatar;
			$ply['name'] = $prof_name;
			
			$inf->updateUserInfo( $ply['uid'], $prof_name, $prof_avatar, $row['avatarfull'] );
			
			break;
		}
	} );
	$steamquery->querySummaries( $steamids );
}

$table->output( $res ? $plys : 'No results were found!' );

include_once( 'pages/footer.php' );
?>