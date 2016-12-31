<?php
require_once( INF_INC_DIR . '/infcommon.php' );

class InfSteamQuery
{
	protected $query_func;
	
	function __construct( $query_func )
	{
		if ( !InfCommon::hasSteamAPIKey() )
		{
			throw new Exception( 'No Steam API key!' );
		}
		
		$this->query_func = $query_func;
	}
	
	public function querySummaries( $values )
	{
		if ( is_array( $values ) )
		{
			if ( !count( $values ) ) return;
			
			$this->queryPlayersSummaries( $values );
		}
		else
		{
			$this->queryPlayerSummaries( $values );
		}
	}
	
	protected function queryPlayersSummaries( $steamids )
	{
		$q = '';
		
		foreach ( $steamids as $steamid )
		{
			$q .= ( $q != '' ? ',' : '' ) . $steamid;
		}
		
		$contents = @file_get_contents( 'http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=' . InfCommon::getSteamAPIKey() . '&steamids=' . $q );
		
		$contents = @json_decode( $contents, true );
		
		$func = $this->query_func;
		
		if ( isset( $contents['response']['players'] ) )
		{
			foreach ( $contents['response']['players'] as $ply )
			{
				$func( $ply );
			}
		}
	}
	
	protected function queryPlayerSummaries( $steam64 )
	{
		$contents = @file_get_contents( 'http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=' . InfCommon::getSteamAPIKey() . '&steamids=' . $steam64 );
		
		$contents = @json_decode( $contents, true );
		
		$func = $this->query_func;
		
		if ( isset( $contents['response']['players'][0] ) )
		{
			$func( $contents['response']['players'][0] );
		}
	}
}
?>