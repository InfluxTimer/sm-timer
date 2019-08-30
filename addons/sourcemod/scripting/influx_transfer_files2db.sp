#include <sourcemod>

#include <influx/core>

#undef REQUIRE_PLUGIN
#include <influx/zones>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Files to DB",
    description = "Transfer run & zone files to database",
    version = INF_VERSION
};

public void OnPluginStart()
{
    RegAdminCmd( "sm_files2db", Cmd_Transfer, ADMFLAG_ROOT );
}

public Action Cmd_Transfer( int client, int args )
{
    if ( client ) return Plugin_Handled;
    
    
    Handle db = Influx_GetDB();
    
    LogMessage( INF_CON_PRE..."Beginning to transfer runs & zones to database..." );
    
    
    char szPath[PLATFORM_MAX_PATH];
    char szFile[PLATFORM_MAX_PATH];
    char szMap[PLATFORM_MAX_PATH];
    char szQuery[512];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "influxruns" );
    
    DirectoryListing dir = OpenDirectory( szPath, false );
    
    FileType type;
    while ( dir.GetNext( szFile, sizeof( szFile ), type ) )
    {
        if ( type != FileType_File )
            continue;
        
        
        // This is the example file?
        if ( szFile[0] == '_' )
            continue;
        
        
        int dotpos = -1;
        int len = strlen( szFile );
        
        for ( int i = 0; i < len; i++ )
        {
            if ( szFile[i] == '.' ) dotpos = i;
        }
        
        
        
        strcopy( szMap, sizeof( szMap ), szFile );
        if ( dotpos != -1 )
            szMap[dotpos] = 0;
        
        FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...INF_TABLE_MAPS..." (mapname) VALUES ('%s')", szMap );
        
        
        SQL_TQuery( db, Thrd_Empty, szQuery, _, DBPrio_Normal );
    }
    
    
    delete dir;
    
    
    SQL_TQuery( db, Thrd_Maps, "SELECT mapid,mapname FROM "...INF_TABLE_MAPS, _, DBPrio_Normal );
    
    
    return Plugin_Handled;
}

public void Thrd_Empty( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "inserting data into database" );
    }
}

public void Thrd_Maps( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "transferring run & zone data" );
        return;
    }
    
    
    char szPath[PLATFORM_MAX_PATH];
    char szMap[128];
    char szQuery[512];
    char szData[1024];
    KeyValues kv;

    while ( SQL_FetchRow( res ) )
    {
        int mapid = SQL_FetchInt( res, 0 );
        SQL_FetchString( res, 1, szMap, sizeof( szMap ) );
        
        LogMessage( INF_CON_PRE..."Inserting map '%s' runs and zones to database...", szMap );
        
        
        // Runs
        
        
        BuildPath( Path_SM, szPath, sizeof( szPath ), "influxruns/%s.ini", szMap );
        
        kv = new KeyValues( "Runs" );
        kv.ImportFromFile( szPath );
        
        bool ret;
        for ( ret = kv.GotoFirstSubKey(); ret; ret = kv.GotoNextKey() )
        {
            int runid = kv.GetNum( "id", -1 );
            if ( !VALID_RUN( runid ) )
                continue;
            
            
            kv.ExportToString( szData, sizeof( szData ) );
            
            if ( !Inf_DB_GetEscaped( db, szData, sizeof( szData ), "" ) )
            {
                LogError( INF_CON_PRE..."Failed to escape run data string! (%i)", runid );
                continue;
            }
            
            
            FormatEx(
                szQuery,
                sizeof( szQuery ),
                "INSERT INTO "...INF_TABLE_RUNS..." (mapid,runid,rundata) VALUES (%i,%i,'%s')",
                mapid,
                runid,
                szData );
                
            SQL_TQuery( db, Thrd_Empty, szQuery, _, DBPrio_Normal );
        }
        
        delete kv;
        
        
        
        // Zones
        
        
        BuildPath( Path_SM, szPath, sizeof( szPath ), "influxzones/%s.ini", szMap );
        
        kv = new KeyValues( "Zones" );
        kv.ImportFromFile( szPath );
        
        for ( ret = kv.GotoFirstSubKey(); ret; ret = kv.GotoNextKey() )
        {
            int zoneid = kv.GetNum( "id", -1 );
            
            kv.ExportToString( szData, sizeof( szData ) );
            
            if ( !Inf_DB_GetEscaped( db, szData, sizeof( szData ), "" ) )
            {
                LogError( INF_CON_PRE..."Failed to escape zone data string! (%i)", zoneid );
                continue;
            }
            
            
            FormatEx(
                szQuery,
                sizeof( szQuery ),
                "INSERT INTO "...INF_TABLE_ZONES..." (mapid,zoneid,zonedata) VALUES (%i,%i,'%s')",
                mapid,
                zoneid,
                szData );
                
            SQL_TQuery( db, Thrd_Empty, szQuery, _, DBPrio_Normal );
        }
        
        delete kv;
    }
    
    
    LogMessage( INF_CON_PRE..."Done inserting! Wait a moment for queries to finish." );
}
