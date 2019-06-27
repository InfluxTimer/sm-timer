#include <sourcemod>

#include <influx/core>

#undef REQUIRE_PLUGIN
#include <influx/zones>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - DB to Files",
    description = "Transfer run & zone database entries to files",
    version = INF_VERSION
};

public void OnPluginStart()
{
    RegAdminCmd( "sm_db2files", Cmd_Transfer, ADMFLAG_ROOT );
}

public Action Cmd_Transfer( int client, int args )
{
    if ( client ) return Plugin_Handled;
    
    
    Handle db = Influx_GetDB();
    
    LogMessage( INF_CON_PRE..."Beginning to transfer runs & zones to file..." );
    
    
    SQL_TQuery( db, Thrd_Runs,
        "SELECT r.mapid,runid,rundata,mapname "...
        "FROM "...INF_TABLE_RUNS..." AS r INNER JOIN "...INF_TABLE_MAPS..." AS m ON r.mapid=m.mapid "...
        "ORDER BY r.mapid" );
        
    SQL_TQuery( db, Thrd_Zones,
        "SELECT z.mapid,zoneid,zonedata,mapname "...
        "FROM "...INF_TABLE_ZONES..." AS z INNER JOIN "...INF_TABLE_MAPS..." AS m ON z.mapid=m.mapid "...
        "ORDER BY z.mapid" );
    
    return Plugin_Handled;
}

public void Thrd_Runs( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "transferring run data" );
        return;
    }
    
    
    LogMessage( INF_CON_PRE..."Beginning to create run files..." );
    
    
    char szMapName[256];
    char szData[1024];
    KeyValues kvfile = null;
    
    int lastmapid = -1;

    while ( SQL_FetchRow( res ) )
    {
        int mapid = SQL_FetchInt( res, 0 );
        int runid = SQL_FetchInt( res, 1 );
        
        SQL_FetchString( res, 2, szData, sizeof( szData ) );
        
        if ( mapid != lastmapid )
        {
            if ( kvfile != null )
            {
                SaveToRunsFile( kvfile, szMapName );
            }
            
            
            kvfile = new KeyValues( "Runs" );
            
            SQL_FetchString( res, 3, szMapName, sizeof( szMapName ) );
            
            lastmapid = mapid;
        }
        
        
        KeyValues kv = new KeyValues( "TempKeyValues" );
        kv.ImportFromString( szData, "TempKeyValues2" );
        
        kv.SetNum( "id", runid );
        
        char szSection[128];
        kv.GetSectionName( szSection, sizeof( szSection ) );
        
        kvfile.JumpToKey( szSection, true );
        
        kvfile.Import( kv );
        
        kvfile.Rewind();
        
        delete kv;
    }
    
    if ( kvfile != null )
    {
        SaveToZonesFile( kvfile, szMapName );
    }
    
    
    LogMessage( INF_CON_PRE..."Ended creating run files!" );
}

public void Thrd_Zones( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "transferring zone data" );
        return;
    }
    
    
    LogMessage( INF_CON_PRE..."Beginning to create zone files..." );
    
    
    char szMapName[256];
    char szData[1024];
    KeyValues kvfile = null;
    
    int lastmapid = -1;

    while ( SQL_FetchRow( res ) )
    {
        int mapid = SQL_FetchInt( res, 0 );
        int zoneid = SQL_FetchInt( res, 1 );
        
        SQL_FetchString( res, 2, szData, sizeof( szData ) );
        
        if ( mapid != lastmapid )
        {
            if ( kvfile != null )
            {
                SaveToZonesFile( kvfile, szMapName );
            }
            
            
            kvfile = new KeyValues( "Zones" );
            
            SQL_FetchString( res, 3, szMapName, sizeof( szMapName ) );
            
            lastmapid = mapid;
        }
        
        
        KeyValues kv = new KeyValues( "TempKeyValues" );
        kv.ImportFromString( szData, "TempKeyValues2" );
        
        kv.SetNum( "id", zoneid );
        
        
        char szSection[128];
        kv.GetSectionName( szSection, sizeof( szSection ) );
        
        kvfile.JumpToKey( szSection, true );
        
        kvfile.Import( kv );
        
        kvfile.Rewind();
        
        delete kv;
    }
    
    if ( kvfile != null )
    {
        SaveToZonesFile( kvfile, szMapName );
    }
    
    
    LogMessage( INF_CON_PRE..."Ended creating zone files!" );
}

stock void SaveToZonesFile( KeyValues &kvfile, const char[] szMapName )
{
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "influxzones/%s.ini", szMapName );
    
    kvfile.ExportToFile( szPath );
    
    delete kvfile;
    kvfile = null;
    
    
    LogMessage( INF_CON_PRE..."Moved %s zones.", szMapName );
}

stock void SaveToRunsFile( KeyValues &kvfile, const char[] szMapName )
{
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "influxruns/%s.ini", szMapName );
    
    kvfile.ExportToFile( szPath );
    
    delete kvfile;
    kvfile = null;
    
    
    LogMessage( INF_CON_PRE..."Moved %s runs.", szMapName );
}
