<?php
class InfCommon
{
	public static function redirect( $page = 'index.php' )
	{
		header( 'Location: ' . $page );
		exit;
	}
	
	public static function hasSteamAPIKey() { return ( INF_STEAMWEBAPIKEY != '' ); }
	
	public static function getSteamAPIKey() { return INF_STEAMWEBAPIKEY; }
	
	public static function steamId3To64( $str )
	{
		$matches = array();
		
		if ( !preg_match( "/[0-9]{1,}]/", $str, $matches ) ) return '';
		
		
		$steam64 = bcadd( '76561197960265728', rtrim( $matches[0], ']' ) );
		
		$correctsteam = explode( '.', $steam64 );
		
		return ( $correctsteam ) ? $correctsteam[0] : $steam64;
	}
	
	public static function steamId64To3( $str )
	{
		$matches = array();
		if ( !preg_match( "/[0-9]{17,}/", $str, $matches ) ) return '';
		
		
		$steam3 = bcsub( $matches[0], '76561197960265728' );
		
		$correctsteam = explode( '.', $steam3 );
		
		$steam3 = $correctsteam ? $correctsteam[0] : $steam3;
		
		return '[U:1:' . $steam3 . ']';
	}
	
	public static function getRunName( $runid )
	{
		if ( $runid == 1 ) return 'Main';
		
		return 'Misc #' . ($runid - 1);
	}
	
	public static function formatSeconds( $secs )
	{
		// sprintf only likes formatting float values for some reason. This is why there are a lot of casting.
		$secs = (float)$secs;
		
		$mins = (float)( floor( $secs / 60.0 ) );
		
		$secs -= (float)($mins * 60);
		
		$hrs_format = '';
		
		if ( $mins >= 60.0 )
		{
			$int_h = (int)( floor( $mins / 60.0 ) );
			
			$hrs_format = sprintf( '%.0f:', (float)$int_h );
			
			$mins = $mins - $int_h * 60;
		}
		
		return sprintf( '%s%02.0f:%05.2f', $hrs_format, $mins, $secs );
	}
	
	public static function formatDate( $date )
	{
		return str_replace( '-', '/', $date );
	}
}
?>