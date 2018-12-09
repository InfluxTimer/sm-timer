
stock void DB_Init()
{
#if defined DISABLE_CREATE_SQL_TABLES
    DISABLE_CREATE_SQL_TABLES
#endif

    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    SQL_TQuery( db, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_SIMPLERANKS..." (" ...
        "uid INT NOT NULL," ...
        "cachedpoints INT NOT NULL," ...
        "chosenrank VARCHAR(127)," ...
        "PRIMARY KEY(uid))", _, DBPrio_High );
        
    SQL_TQuery( db, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_SIMPLERANKS_HISTORY..." (" ...
        "uid INT NOT NULL," ...
        "mapid INT NOT NULL," ...
        "runid INT NOT NULL," ...
        "mode INT NOT NULL," ...
        "style INT NOT NULL," ...
        "rewardpoints INT NOT NULL," ...
        "wasfirst INT NOT NULL," ...
        "PRIMARY KEY(uid,mapid,runid,mode,style))", _, DBPrio_High );
        
    SQL_TQuery( db, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_SIMPLERANKS_MAPS..." (" ...
        "mapid INT NOT NULL," ...
        "runid INT NOT NULL," ...
        "rewardpoints INT NOT NULL," ...
        "PRIMARY KEY(mapid,runid))", _, DBPrio_High );
}

stock void DB_InitMap( int mapid )
{
    Handle db = Influx_GetDB();
    
    static char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT runid,rewardpoints FROM "...INF_TABLE_SIMPLERANKS_MAPS..." WHERE mapid=%i", mapid );
    
    
    SQL_TQuery( db, Thrd_InitMap, szQuery, _, DBPrio_Normal );
}

stock void DB_InitClient( int client )
{
    Handle db = Influx_GetDB();
    
    
    int userid = GetClientUserId( client );
    
    int uid = Influx_GetClientId( client );
    
    
    static char szQuery[256];
    
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT cachedpoints,chosenrank FROM "...INF_TABLE_SIMPLERANKS..." WHERE uid=%i", uid );
    
    
    SQL_TQuery( db, Thrd_InitClient, szQuery, userid, DBPrio_Normal );
}

stock void DB_CheckClientRecCount( int client, int runid, int mode, int style )
{
    Handle db = Influx_GetDB();
    
    
    int mapid = Influx_GetCurrentMapId();
    int uid = Influx_GetClientId( client );
    
    
    // See if the player has already beaten this map.
    decl data[5];
    
    data[0] = GetClientUserId( client );
    data[1] = mapid;
    data[2] = runid;
    data[3] = mode;
    data[4] = style;
    
    ArrayList array = new ArrayList( sizeof( data ) );
    array.PushArray( data );

    
    static char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT mode,style,rewardpoints,wasfirst FROM "...INF_TABLE_SIMPLERANKS_HISTORY..." WHERE uid=%i AND mapid=%i AND runid=%i", 
        uid,
        mapid,
        runid );
    
    SQL_TQuery( db, Thrd_CheckClientRecCount, szQuery, array, DBPrio_Normal );
}

stock void DB_IncClientPoints( int client, int runid, int mode, int style, int reward, bool bFirst, bool bAdjustOld = false )
{
    Handle db = Influx_GetDB();
    
    static char szQuery[512];
    
    int userid = GetClientUserId( client );
    
    int uid = Influx_GetClientId( client );
    int mapid = Influx_GetCurrentMapId();
    
    
    FormatEx( szQuery, sizeof( szQuery ),
        "UPDATE "...INF_TABLE_SIMPLERANKS..." SET cachedpoints=cachedpoints+%i WHERE uid=%i",
        reward,
        uid );
    
    SQL_TQuery( db, Thrd_Empty, szQuery, userid, DBPrio_Normal );
    
    
    // We're updating an old reward, just set the reward.
    if ( bAdjustOld )
    {
        reward = CalcReward( runid, mode, style, bFirst );
    }
    
    FormatEx( szQuery, sizeof( szQuery ),
        "REPLACE INTO "...INF_TABLE_SIMPLERANKS_HISTORY..." (uid,mapid,runid,mode,style,rewardpoints,wasfirst) VALUES (%i,%i,%i,%i,%i,%i,%i)",
        uid,
        mapid,
        runid,
        mode,
        style,
        reward,
        bFirst ? 1 : 0 );
    
    SQL_TQuery( db, Thrd_Empty, szQuery, userid, DBPrio_Normal );
}

stock void DB_IncCachedPoints( int client, int reward )
{
    Handle db = Influx_GetDB();
    
    static char szQuery[512];
    
    
    int userid = GetClientUserId( client );
    
    int uid = Influx_GetClientId( client );
    
    FormatEx( szQuery, sizeof( szQuery ),
        "UPDATE "...INF_TABLE_SIMPLERANKS..." SET cachedpoints=cachedpoints+%i WHERE uid=%i",
        reward,
        uid );
    
    SQL_TQuery( db, Thrd_Empty, szQuery, userid, DBPrio_Normal );
}

stock void DB_UpdateMapReward( int mapid, int runid, int reward, int issuer = 0 )
{
    Handle db = Influx_GetDB();
    
    char szQuery[256];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "REPLACE INTO "...INF_TABLE_SIMPLERANKS_MAPS..." (mapid,runid,rewardpoints) VALUES (%i,%i,%i)",
        mapid,
        runid,
        reward );
    
    SQL_TQuery( db, Thrd_Empty, szQuery, issuer ? GetClientUserId( issuer ) : 0, DBPrio_Normal );
}

stock void DB_UpdateClientChosenRank( int client, const char[] szRank )
{
    Handle db = Influx_GetDB();
    
    decl String:szSafe[MAX_RANK_SIZE];
    strcopy( szSafe, sizeof( szSafe ), szRank );
    
    RemoveChars( szSafe, "`'\"" );
    
    
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "UPDATE "...INF_TABLE_SIMPLERANKS..." SET chosenrank='%s' WHERE uid=%i",
        szSafe,
        Influx_GetClientId( client ) );
    
    SQL_TQuery( db, Thrd_Empty, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_SetMapRewardByName( int client, int runid, int reward, const char[] szMap )
{
    Handle db = Influx_GetDB();
    
    decl String:szSafe[64];
    strcopy( szSafe, sizeof( szSafe ), szMap );
    
    RemoveChars( szSafe, "`'\"" );
    
    
    decl data[3];
    data[0] = ( client ) ? GetClientUserId( client ) : 0;
    data[1] = runid;
    data[2] = reward;
    
    ArrayList array = new ArrayList( sizeof( data ) );
    array.PushArray( data );
    
    
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT mapid,mapname FROM "...INF_TABLE_MAPS..." WHERE mapname LIKE '%%%s%%'", szSafe );
    
    SQL_TQuery( db, Thrd_SetMapReward, szQuery, array, DBPrio_Normal );
}

stock void DB_DisplayTopRanks( int client, int nToPrint )
{
    Handle db = Influx_GetDB();
    
    decl data[2];
    data[0] = GetClientUserId( client );
    data[1] = nToPrint;
    
    ArrayList array = new ArrayList( sizeof( data ) );
    array.PushArray( data );
    
    
    static char szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT cachedpoints,_u.name " ...
        "FROM "...INF_TABLE_SIMPLERANKS..." AS _s INNER JOIN "...INF_TABLE_USERS..." AS _u ON _s.uid=_u.uid " ...
        "ORDER BY cachedpoints DESC LIMIT %i", nToPrint );
    
    SQL_TQuery( db, Thrd_DisplayTopRanks, szQuery, array, DBPrio_Normal );
}
