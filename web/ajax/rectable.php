<?php
require_once( '../inc/infdef.php' ); // Must always be included first.
require_once( INF_INC_DIR . '/infdb.php' );
require_once( INF_INC_DIR . '/infcommon.php' );
require_once( INF_INC_DIR . '/infresponse.php' );
require_once( INF_INC_DIR . '/infsteamquery.php' );



$inf = new InfDb();


$uid = -1;
$mapid = -1;


$offset = isset( $_POST['offset'] ) ? (int)$_POST['offset'] : 0;
$num = isset( $_POST['num'] ) ? (int)$_POST['num'] : 0;
$type = isset( $_POST['type'] ) ? $_POST['type'] : '';

$steamid = isset( $_POST['steamid'] ) ? $_POST['steamid'] : '';
$mapname = isset( $_POST['mapname'] ) ? $_POST['mapname'] : '';
$search = isset( $_POST['search'] ) ? $_POST['search'] : '';

if ( $steamid != '' )
{
	$ret = $inf->getUserInfoBySteam( InfCommon::steamId64To3( $steamid ) );
	
	if ( $ret )
	{
		$uid = $ret['uid'];
	}
}

if ( $mapname != '' )
{
	$mapid = $inf->getMapByName( $mapname );
}

if ( $offset >= 0 )
{
	if ( $num <= 0 )
	{
		$num = 1;
	}
	else if ( $num > 15 )
	{
		$num = 15;
	}
	
	
	$response = new InfAjaxResponse_RecTable();
	
	switch ( $type )
	{
		case 'recentmaprecords' :
		case 'recentmaptoprecords' :
			if ( $type == 'recentmaprecords' )
			{
				$ret = $inf->getRecentRecords( -1, $mapid, -1, -1, -1, $num, $offset * $num );
			}
			else
			{
				$ret = $inf->getRecentSRs( -1, $mapid, -1, -1, -1, $num, $offset * $num );
			}
			
			$response->addColumn( 'player', function( $row ){
				return '<a href="user.php?u=' . InfCommon::steamId3To64( $row['steamid'] ) . '">' . htmlspecialchars( $row['name'] ) . '</a>';
			} );
			$response->addColumn( 'style', function( $row ) {
				global $inf;
				return $inf->getFullStyleName( $row['mode'], $row['style'] );
			} );
			$response->addColumn( 'run', function( $row ){return InfCommon::getRunName( $row['runid'] );} );
			$response->addColumn( 'time', function( $row ){return InfCommon::formatSeconds( $row['rectime'] );} );
			$response->addColumn( 'date', function( $row ){return InfCommon::formatDate( $row['recdate'] );} );
			break;
		case 'recentrecords' :
		case 'recenttoprecords' :
			if ( $type == 'recentrecords' )
			{
				$ret = $inf->getRecentRecords( $uid, -1, -1, -1, -1, $num, $offset * $num );
			}
			else
			{
				$ret = $inf->getRecentSRs( $uid, -1, -1, -1, -1, $num, $offset * $num );
			}
			
			$response->addColumn( 'map', function( $row ) {
				return '<a href="map.php?m='. $row['mapname'] . '">' . $row['mapname'] . '</a>';
			} );
			$response->addColumn( 'player', function( $row ){
				return '<a href="user.php?u=' . InfCommon::steamId3To64( $row['steamid'] ) . '">' . htmlspecialchars( $row['name'] ) . '</a>';
			} );
			$response->addColumn( 'style', function( $row ) {
				global $inf;
				return $inf->getFullStyleName( $row['mode'], $row['style'] );
			} );
			$response->addColumn( 'run', function( $row ){return InfCommon::getRunName( $row['runid'] );} );
			$response->addColumn( 'time', function( $row ){return InfCommon::formatSeconds( $row['rectime'] );} );
			$response->addColumn( 'date', function( $row ){return InfCommon::formatDate( $row['recdate'] );} );
			break;
		case 'topplayers' :
			$ret = $inf->getTopPlayers( -1, -1, -1, -1, $num, $offset * $num );
			
			$response->addColumn( 'player', function( $row ){
				return '<a href="user.php?u=' . InfCommon::steamId3To64( $row['steamid'] ) . '">' . htmlspecialchars( $row['name'] ) . '</a>';
			} );
			$response->addColumn( 'topnum', function( $row ){return $row['numrecs'];} );
			
			break;
		case 'searchplayers' :
			$ret = $inf->searchforPlayers( $search, $num, $offset * $num );
			
			$response->addColumn( 'player', function( $row ){
				$avatar = isset( $row['_steam_avatar'] ) ? "<img class=\"search-res-img\" src=\"{$row['_steam_avatar']}\">" : "";
				
				$name = '<p class="search-res-name">' . htmlspecialchars( $row['name'] ) . '</p>';
				
				$ulink = 'user.php?u=' . InfCommon::steamId3To64( $row['steamid'] );
				
				return '<a href="' . $ulink . '">' . $avatar . $name . '</a>';
			} );
			$response->addColumn( 'date', function( $row ) {return InfCommon::formatDate( $row['joindate'] );} );
			
			if ( $ret && InfCommon::hasSteamAPIKey() )
			{
				$steamids = array();
				
				$curdate = strtotime( $inf->getDate() );
				
				foreach ( $ret as &$ply )
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
					}
					else
					{
						$ply['_steam_avatar'] = $sinfo['steam_avatar'];
					}
					
					$ply['_steam64'] = $steam64;
				}
				
				$steamquery = new InfSteamQuery( function( $row ) {
					global $ret;
					global $inf;
					foreach ( $ret as &$ply )
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
			
			
			break;
		default :
			$ret = false;
	}
	
	$response->respond( $ret );
}
?>