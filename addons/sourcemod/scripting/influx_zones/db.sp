stock void DB_Init()
{
#if defined DISABLE_CREATE_SQL_TABLES
    DISABLE_CREATE_SQL_TABLES
#endif
	
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    SQL_TQuery( db, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_ZONES..." (" ...
        "mapid INT NOT NULL," ...
        "zoneid INT NOT NULL," ...
        "zonedata VARCHAR(512)," ...
        "PRIMARY KEY(mapid,zoneid))", _, DBPrio_High );
}

stock void DB_LoadZones()
{
    Handle db = Influx_GetDB();
    
    int mapid = Influx_GetCurrentMapId();
    
    
    decl String:szQuery[192];
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT " ...
        "zoneid,zonedata " ...
        "FROM "...INF_TABLE_ZONES..." " ...
        "WHERE mapid=%i " ...
        "ORDER BY zoneid ASC",
        mapid );
    
    
    SQL_TQuery( db, Thrd_GetZones, szQuery, _, DBPrio_High );
}

stock void DB_RemoveZone( int zoneid )
{
    Handle db = Influx_GetDB();
    
    int mapid = Influx_GetCurrentMapId();
    
    
    decl String:szQuery[192];
    FormatEx( szQuery, sizeof( szQuery ),
        "DELETE FROM "...INF_TABLE_ZONES..." WHERE mapid=%i AND zoneid=%i",
        mapid,
        zoneid );
        
    SQL_TQuery( db, Thrd_Empty, szQuery, _, DBPrio_Normal );
}

stock int DB_SaveZones( ArrayList kvs )
{
    Handle db = Influx_GetDB();
    
    int mapid = Influx_GetCurrentMapId();
    
    static char szQuery[2048];
    
    decl String:szZoneData[1024];
    
    int num = 0;
    
    for ( int i = 0; i < kvs.Length; i++ )
    {
        KeyValues zonedata = view_as<KeyValues>( kvs.Get( i, 0 ) );
        int zoneid = kvs.Get( i, 1 );
        
        
        zonedata.ExportToString( szZoneData, sizeof( szZoneData ) );
        
#if defined DEBUG_DB_ZONE
        PrintToServer( INF_DEBUG_PRE..."Saving zone data:\n%s", szZoneData );
#endif
        
        if ( !Inf_DB_GetEscaped( db, szZoneData, sizeof( szZoneData ) ) )
        {
            LogError( INF_CON_PRE..."Failed to escape zone data string! (%i)", zoneid );
            continue;
        }
        
#if defined DEBUG_DB_ZONE
        PrintToServer( INF_DEBUG_PRE..."Escaped:\n%s", szZoneData );
#endif
        
        
        FormatEx(
            szQuery,
            sizeof( szQuery ),
            "REPLACE INTO "...INF_TABLE_ZONES..." (mapid,zoneid,zonedata) VALUES (%i,%i,'%s')",
            mapid,
            zoneid,
            szZoneData );
            
        SQL_TQuery( db, Thrd_Empty, szQuery, _, DBPrio_Normal );
        
        ++num;
    }
    
    return num;
}
