<?php
define( 'INF_TABLE_USERS', 'inf_users' );
define( 'INF_TABLE_MAPS', 'inf_maps' );
define( 'INF_TABLE_TIMES', 'inf_times' );
define( 'INF_TABLE_CPTIMES', 'inf_cptimes' );

define( 'INF_TABLE_USERS_STEAMCACHE', 'inf_users_steamcache' );


class InfDb
{
	private $pdo;
	
	private $styles = false;
	
	function __construct()
	{
		$options = array();
		
		if ( defined( 'INF_SQL_PERSISTENT' ) && INF_SQL_PERSISTENT )
		{
			$options[PDO::ATTR_PERSISTENT] = true;
		}
		
		try
		{
			$this->pdo = new PDO(
				'mysql:host=' . INF_HOST . ';port=' . INF_PORT . ';dbname=' . INF_DBNAME . ';charset=utf8',
				INF_USER,
				INF_PASS,
				$options );
		}
		catch ( PDOException $e )
		{
			if ( INF_DEBUG )
			{
				exit( 'Cannot connect to database! Error: ' . $e->getMessage() );
			}
			
			exit( 'Sorry, something went wrong with the database! Enable debug mode in the configuration file to know more.' );
		}
	}
	
	public function getDB()
	{
		return $this->pdo;
	}
	
	public function getDate()
	{
		$res = $this->pdo->prepare( 'SELECT NOW() AS date' );
		
		if ( !$res || !$res->execute() )
		{
			return false;
		}
		
		
		$row = $res->fetch();
		
		return ( $row && isset( $row['date'] ) ) ? $row['date'] : false;
	}
	
	private function parseStyles()
	{
		$str = @file_get_contents( INF_INC_DIR . '/../styles.txt' );
		
		if ( !$str )
		{
			exit( 'Could not find styles.txt' );
		}
		
		
		$lines = explode( "\n", $str );
		
		if ( !$lines )
		{
			exit( 'Could not open styles.txt' );
		}
		
		$array = array();
		$i = 0;
		
		$ismode = false;
		
		foreach ( $lines as $line )
		{
			$pos = strpos( $line, ';' );
			if ( $pos !== false ) continue;
			
			
			$line = rtrim( $line );
			
			
			$pos = strpos( $line, '=' );
			
			if ( $pos !== false )
			{
				$array[$i] = array();
				
				$array[$i]['ismode'] = $ismode;
				
				$array[$i]['name'] = substr( $line, $pos + 1 );
				$array[$i]['value'] = (int)substr( $line, 0, $pos );
				
				++$i;
			}
			else if ( $line == 'modes' )
			{
				$ismode = true;
			}
		}
		
		$this->styles = $array;
	}
	
	/*
		Combines getModeName & getStyleName
	*/
	public function getFullStyleName( $value_mode, $value_style )
	{
		$mode = $this->getModeName( $value_mode );
		$style = $this->getStyleName( $value_style );
		
		
		if ( $mode == false && $style == false ) return 'N/A';
		
		
		if ( !$mode )
		{
			$mode = '';
		}
		
		if ( !$style )
		{
			$style = '';
		}
		else
		{
			$style .= ' ';
		}
		
		return $style . $mode;
	}
	
	public function getModeName( $value )
	{
		if ( !$this->styles ) $this->parseStyles();
		
		
		$value = (int)$value;
		
		foreach ( $this->styles as $style )
		{
			if ( !$style['ismode'] ) continue;
			
			
			if ( $style['value'] == $value )
			{
				return $style['name'];
			}
		}
		
		return false;
	}
	
	public function getStyleName( $value )
	{
		if ( !$this->styles ) $this->parseStyles();
		
		
		$value = (int)$value;
		
		foreach ( $this->styles as $style )
		{
			if ( $style['ismode'] ) continue;
			
			
			if ( $style['value'] == $value )
			{
				return $style['name'];
			}
		}
		
		return false;
	}
	
	public function getMapByName( $mapname )
	{
		$steamid = preg_replace( "/[\'\";)(]/", '', $mapname );
		
		if ( !strlen( $mapname ) )
		{
			return false;
		}
		
		
		$res = $this->pdo->prepare( 'SELECT * FROM '.INF_TABLE_MAPS.' WHERE mapname=:mapname' );
		
		if ( !$res )
		{
			return false;
		}
		
		$res->bindParam( ':mapname', $mapname );
		
		
		if ( !$res->execute() )
		{
			return false;
		}
		
		
		$ret = $res->fetch();
		
		return ( $ret ) ? (int)$ret['mapid'] : false;
	}
	
	/*
		Returns all columns from user.
	*/
	public function getUserInfoBySteam( $steamid )
	{
		$steamid = preg_replace( "/[\'\";)(]/", '', $steamid );
		
		if ( !strlen( $steamid ) )
		{
			return false;
		}
		
		
		$res = $this->pdo->prepare( 'SELECT * FROM '.INF_TABLE_USERS.' WHERE steamid=:steamid' );
		
		if ( !$res )
		{
			return false;
		}
		
		$res->bindParam( ':steamid', $steamid );
		
		
		if ( !$res->execute() )
		{
			return false;
		}
		
		
		$ret = $res->fetch();
		
		return ( $ret ) ? $ret : false;
	}
	
	public function getUserSteamInfo( $uid )
	{
		$uid = (int)$uid;
		
		$res = $this->pdo->prepare( "SELECT * FROM ".INF_TABLE_USERS_STEAMCACHE." WHERE uid=:uid" );

		if ( !$res )
		{
			return false;
		}
		
		
		$res->bindParam( ':uid', $uid, PDO::PARAM_INT );
		
		
		if ( !$res->execute() )
		{
			return false;
		}
		
		
		return $res->fetch();
	}
	
	public function updateUserInfo( $uid, $name, $avatar, $avatarfull )
	{
		$uid = (int)$uid;
		
		$this->updateUserName( $uid, $name );
		
		$this->updateUserSteamCache( $uid, $avatar, $avatarfull );
	}
	
	private function updateUserName( $uid, $name )
	{
		$res = $this->pdo->prepare( 'UPDATE '.INF_TABLE_USERS.' SET name=:name WHERE uid=:uid' );

		if ( !$res )
		{
			return false;
		}
		
		
		$res->bindParam( ':name', $name );
		
		$res->bindParam( ':uid', $uid, PDO::PARAM_INT );
		
		
		return $res->execute() ? true : false;
	}
	
	private function updateUserSteamCache( $uid, $avatar, $avatarfull )
	{
		$res = $this->pdo->prepare( 'REPLACE INTO '.INF_TABLE_USERS_STEAMCACHE.' (uid,steam_avatar,steam_avatarfull) VALUES (:uid,:avatar,:avatarfull)' );

		if ( !$res )
		{
			return false;
		}
		
		
		$res->bindParam( ':uid', $uid, PDO::PARAM_INT );
		
		$res->bindParam( ':avatar', $avatar );
		$res->bindParam( ':avatarfull', $avatarfull );
		
		
		return $res->execute() ? true : false;
	}
	
	/*
		Returns a number of records found. If failed, returns false.
	*/
	public function getRecordsCount( $uid = -1, $mapid = -1, $runid = -1, $mode = -1, $style = -1 )
	{
		$uid = (int)$uid;
		$mapid = (int)$mapid;
		$runid = (int)$runid;
		$mode = (int)$mode;
		$style = (int)$style;
		
		
		$where = self::formatWhereClause( $binds, $uid, $mapid, $runid, $mode, $style );
		
		if ( $where != '' )
		{
			$where = ' WHERE ' . $where;
		}
		
		if ( defined( 'INF_ALLOWED_MAPS_REGEX' ) )
		{
			$where .= ( $where != '' ? ' AND' : ' WHERE' ) . " mapname REGEXP '" . INF_ALLOWED_MAPS_REGEX . "'";
		}
		
		$res = $this->pdo->prepare( "SELECT COUNT(*) AS count FROM ".INF_TABLE_TIMES. $where );

		if ( !$res )
		{
			return false;
		}
		
		
		self::bindParams( $res, $binds );
		
		
		if ( !$res->execute() )
		{
			return false;
		}
		
		
		$rec = $res->fetch();
		
		return $rec ? (int)$rec['count'] : false;
	}
	
	/*
		Returns an array of recent records. If failed, returns false.
	*/
	public function getRecentRecords( $uid = -1, $mapid = -1, $runid = -1, $mode = -1, $style = -1, $limit = 10, $offset = 0 )
	{
		$uid = (int)$uid;
		$mapid = (int)$mapid;
		$runid = (int)$runid;
		$mode = (int)$mode;
		$style = (int)$style;
		$limit = (int)$limit;
		$offset = (int)$offset;
		
		
		$where = self::formatWhereClause( $binds, $uid, $mapid, $runid, $mode, $style, '_t.' );
		
		if ( $where != '' )
		{
			$where = ' WHERE ' . $where;
		}
		
		if ( defined( 'INF_ALLOWED_MAPS_REGEX' ) )
		{
			$where .= ( $where != '' ? ' AND' : ' WHERE' ) . " mapname REGEXP '" . INF_ALLOWED_MAPS_REGEX . "'";
		}
		
		$res = $this->pdo->prepare( "SELECT * FROM ".INF_TABLE_TIMES." AS _t INNER JOIN ".INF_TABLE_USERS." AS _u ON _t.uid=_u.uid INNER JOIN ".INF_TABLE_MAPS." AS _m ON _t.mapid=_m.mapid{$where} ORDER BY recdate DESC LIMIT :offset,:limit" );

		if ( !$res )
		{
			return false;
		}
		
		
		self::bindParams( $res, $binds );
		
		$res->bindParam( ':offset', $offset, PDO::PARAM_INT );
		$res->bindParam( ':limit', $limit, PDO::PARAM_INT );
		
		
		if ( !$res->execute() )
		{
			return false;
		}
		
		
		return $res->fetchAll();
	}
	
	/*
		Returns an array of recent top records. If failed, returns false.
	*/
	public function getRecentSRs( $uid = -1, $mapid = -1, $runid = -1, $mode = -1, $style = -1, $limit = 10, $offset = 0 )
	{
		$uid = (int)$uid;
		$mapid = (int)$mapid;
		$runid = (int)$runid;
		$mode = (int)$mode;
		$style = (int)$style;
		$limit = (int)$limit;
		$offset = (int)$offset;
		
		
		$where = self::formatWhereClause( $binds, $uid, $mapid, $runid, $mode, $style, '_t.' );
		
		if ( $where != '' )
		{
			$where .= ' AND ';
		}
		
		if ( defined( 'INF_ALLOWED_MAPS_REGEX' ) )
		{
			$where .= "mapname REGEXP '" . INF_ALLOWED_MAPS_REGEX . "' AND ";
		}
		
		$res = $this->pdo->prepare( "SELECT * FROM ".INF_TABLE_TIMES." AS _t INNER JOIN ".INF_TABLE_USERS." AS _u ON _t.uid=_u.uid INNER JOIN ".INF_TABLE_MAPS." AS _m ON _t.mapid=_m.mapid WHERE {$where}rectime=(SELECT MIN(rectime) FROM ".INF_TABLE_TIMES." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style) ORDER BY recdate DESC LIMIT :offset,:limit" );

		if ( !$res )
		{
			return false;
		}
		
		self::bindParams( $res, $binds );
		
		$res->bindParam( ':offset', $offset, PDO::PARAM_INT );
		$res->bindParam( ':limit', $limit, PDO::PARAM_INT );
		
		
		if ( !$res->execute() )
		{
			return false;
		}
		
		
		return $res->fetchAll();
	}
	
	public function getTopPlayers( $mapid = -1, $runid = -1, $mode = -1, $style = -1, $limit = 10, $offset = 0 )
	{
		$mapid = (int)$mapid;
		$runid = (int)$runid;
		$mode = (int)$mode;
		$style = (int)$style;
		$limit = (int)$limit;
		$offset = (int)$offset;
		
		
		$where = self::formatWhereClause( $binds, 0, $mapid, $runid, $mode, $style, '_t.' );
		
		if ( $where != '' )
		{
			$where .= ' AND ';
		}
		
		if ( defined( 'INF_ALLOWED_MAPS_REGEX' ) )
		{
			$where .= "mapname REGEXP '" . INF_ALLOWED_MAPS_REGEX . "' AND ";
		}
		
		$res = $this->pdo->prepare( "SELECT steamid,name,COUNT(*) AS numrecs FROM ".INF_TABLE_TIMES." AS _t INNER JOIN ".INF_TABLE_USERS." AS _u ON _t.uid=_u.uid INNER JOIN ".INF_TABLE_MAPS." AS _m ON _t.mapid=_m.mapid WHERE {$where}rectime=(SELECT MIN(rectime) FROM ".INF_TABLE_TIMES." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style) GROUP BY _t.uid ORDER BY numrecs DESC,name ASC LIMIT :offset,:limit" );
		
		if ( !$res )
		{
			return false;
		}
		
		self::bindParams( $res, $binds );
		
		$res->bindParam( ':offset', $offset, PDO::PARAM_INT );
		$res->bindParam( ':limit', $limit, PDO::PARAM_INT );
		
		
		if ( !$res->execute() )
		{
			return false;
		}
		
		
		return $res->fetchAll();
	}
	
	public function searchforPlayers( $query, $limit = 10, $offset = 0 )
	{
		$query = preg_replace( "/[\'\"]/", '', trim( $query ) );
		
		$query = str_replace( "%", "\\%", $query );
		$query = str_replace( "_", "\\_", $query );
		$query = str_replace( "\\", "\\\\", $query );
		
		if ( $query == '' )
		{
			return false;
		}
		
		$query = '%' . $query . '%';
		
		
		$res = $this->pdo->prepare( 'SELECT * FROM '.INF_TABLE_USERS.' AS _u WHERE name LIKE :query ORDER BY name ASC LIMIT :offset,:limit' );
		
		if ( !$res )
		{
			return false;
		}
		
		$res->bindParam( ':query', $query );
		
		$res->bindParam( ':offset', $offset, PDO::PARAM_INT );
		$res->bindParam( ':limit', $limit, PDO::PARAM_INT );
		
		
		if ( !$res->execute() )
		{
			return false;
		}
		
		
		return $res->fetchAll();
	}
	
	/*
	public function searchforMaps( $query )
	{
		$query = preg_replace( '/\W/', '', $query );
		
		if ( !strlen( $query ) )
		{
			return false;
		}
		
		$query = '%' . $query . '%';
		
		
		$res = $this->pdo->prepare( 'SELECT * FROM '.INF_TABLE_MAPS." AS _m WHERE mapname LIKE :query ESCAPE '\\\\' ORDER BY mapname" );
		
		if ( !$res )
		{
			return false;
		}
		
		$res->bindParam( ':query', $query );
		
		
		if ( !$res->execute() )
		{
			return false;
		}
		
		
		return $res->fetchAll();
	}
	*/
	
	private static function formatWhereClause( &$binds, $uid = 0, $mapid = 0, $runid = 0, $mode = 0, $style = 0, $table = '' )
	{
		$str = '';
		$binds = array();
		
		
		if ( $uid > 0 ) self::formatWhereClauseValue( $str, $table, 'uid', $uid, $binds );
		if ( $mapid > 0 ) self::formatWhereClauseValue( $str, $table, 'mapid', $mapid, $binds );
		if ( $runid > 0 ) self::formatWhereClauseValue( $str, $table, 'runid', $runid, $binds );
		if ( $mode >= 0 ) self::formatWhereClauseValue( $str, $table, 'mode', $mode, $binds );
		if ( $style >= 0 ) self::formatWhereClauseValue( $str, $table, 'style', $style, $binds );
		
		return $str;
	}
	
	private static function formatWhereClauseValue( &$str, $table, $name, $value, &$binds )
	{
		$bindparam = ':' . $name;
		
		if ( $str != '' )
		{
			$str .= ' AND ';
		}
		
		$str .= $table . $name . '=' . $bindparam;
		
		
		$pos = count( $binds );
		
		$binds[$pos] = array();
		$binds[$pos]['name'] = $bindparam;
		$binds[$pos]['value'] = $value;
	}
	
	private static function bindParams( &$res, $binds )
	{
		foreach ( $binds as $bind )
		{
			$res->bindParam( $bind['name'], $bind['value'], PDO::PARAM_INT );
		}
	}
}
?>