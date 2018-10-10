#include <sourcemod>


#undef REQUIRE_PLUGIN
#include <influx/core>

#include <msharedutil/misc>



#define DB_CONFIG_NAME          "ck2influx"


bool g_bLib_Core;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - ckSurf Transfer",
    description = "Transfer ckSurf data to Influx",
    version = INF_VERSION
};

public void OnPluginStart()
{
    RegAdminCmd( "sm_cksurf2influx", Cmd_Transfer, ADMFLAG_ROOT );
    
    // LIBRARIES
    g_bLib_Core = LibraryExists( INFLUX_LIB_CORE );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_CORE ) ) g_bLib_Core = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_CORE ) ) g_bLib_Core = false;
}


stock Handle GetDB()
{
    Handle db = null;
    
    char szError[1024];
    
    if ( SQL_CheckConfig( DB_CONFIG_NAME ) )
    {
        db = SQL_Connect( DB_CONFIG_NAME, true, szError, sizeof( szError ) );
        
        if ( db == null )
            PrintToServer( INF_CON_PRE..."DB error: %s", szError );
    }
    
    if ( db == null && g_bLib_Core )
    {
        db = Influx_GetDB();
        
        PrintToServer( INF_CON_PRE..."Failed to connect to config '%s', defaulting to Influx config...", DB_CONFIG_NAME );
    }
    
    
    if ( db == null )
    {
        SetFailState( INF_CON_PRE..."Failed to retrieve any database handle!" );
    }
    
    return db;
}

public Action Cmd_Transfer( int client, int args )
{
    if ( client ) return Plugin_Handled;
    
    
    LogMessage( INF_CON_PRE..."Beginning to transfer ckSurf zones to Influx..." );
    
    SQL_TQuery(
        GetDB(),
        Thrd_Zones,
        "SELECT mapname,zonegroup,zonetype,pointa_x,pointa_y,pointa_z,pointb_x,pointb_y,pointb_z FROM ck_zones ORDER BY mapname",
        _, DBPrio_High );
        
    
    return Plugin_Handled;
}
 
stock void CreateDirectories()
{
    LogMessage( INF_CON_PRE..."Creating directories..." );
    
    
    decl String:szPath[PLATFORM_MAX_PATH];
    
    BuildPath( Path_SM, szPath, sizeof( szPath ), "influxruns" );
    DirExistsEx( szPath );
    
    BuildPath( Path_SM, szPath, sizeof( szPath ), "influxzones" );
    DirExistsEx( szPath );
}

stock void SaveFiles( KeyValues zonefilekv, ArrayList runs, const char[] szCurSafeMap )
{
    decl String:szPath[PLATFORM_MAX_PATH];
    
    // Create the zone file
    BuildPath( Path_SM, szPath, sizeof( szPath ), "influxzones/%s.ini", szCurSafeMap );
    
    if ( !FileExists( szPath ) )
    {
        PrintToServer( INF_CON_PRE..."Saving zones file %s.ini...", szCurSafeMap );
        
        zonefilekv.ExportToFile( szPath );
    }
    else
    {
        PrintToServer( INF_CON_PRE..."File %s already exists, not saving...", szPath );
    }
    
    
    // Create runs file
    BuildPath( Path_SM, szPath, sizeof( szPath ), "influxruns/%s.ini", szCurSafeMap );
    
    if ( !FileExists( szPath ) )
    {
        PrintToServer( INF_CON_PRE..."Saving runs file %s.ini with %i runs...", szCurSafeMap, runs.Length );
        
        
        KeyValues runkv = new KeyValues( "Runs" );
        char szRunName[128];
        
        for ( int i = 0; i < runs.Length; i++ )
        {
            int runid = runs.Get( i, 0 );
            
            if ( runid == MAIN_RUN_ID )
            {
                strcopy( szRunName, sizeof( szRunName ), "Main" );
            }
            else
            {
                FormatEx( szRunName, sizeof( szRunName ), "Bonus #%i", runid-1 );
            }
            
            runkv.JumpToKey( szRunName, true );
            
            runkv.SetNum( "id", runid );
            
            runkv.GoBack();
        }
        
        runkv.ExportToFile( szPath );
        
        delete runkv;
    }
    else
    {
        PrintToServer( INF_CON_PRE..."File %s already exists, not saving...", szPath );
    }
}

public void Thrd_Zones( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "transferring zone data" );
        return;
    }
    
    if ( !SQL_GetRowCount( res ) )
    {
        LogMessage( INF_CON_PRE..."No rows were received. Either there is nothing there or you haven't connected to the correct database." );
        return;
    }
    
    
    CreateDirectories();
    
    
    decl String:szCurSafeMap[256];
    decl String:szPrevMapName[256];
    szPrevMapName[0] = 0;
    
    
    decl String:szMapName[256];
    decl String:szZoneName[256];
    int zonetype;
    int zonegroup;
    float mins[3];
    float maxs[3];
    
    int zoneid;
    
    decl String:szCoords[256];
    int i;
    
    int nZones = 0;
    int nMaps = 0;
    
    
    PrintToServer( INF_CON_PRE..."Reading zone query results..." );
    
    
   
    KeyValues kv = null;
    ArrayList runs = null;
    
    
    while ( SQL_FetchRow( res ) )
    {
        SQL_FetchString( res, 0, szMapName, sizeof( szMapName ) );
        zonegroup = SQL_FetchInt( res, 1 );
        zonetype = SQL_FetchInt( res, 2 );
        
        for ( i = 0; i < 3; i++ )
            mins[i] = SQL_FetchFloat( res, 3 + i );
        
        for ( i = 0; i < 3; i++ )
            maxs[i] = SQL_FetchFloat( res, 6 + i );
        
        
        // Madness check
        if ( szMapName[0] == 0 )
        {
            PrintToServer( INF_CON_PRE..."Shitty database detected..." );
            continue;
        }
        
        
        // We've ordered it by map, so start a new kv each map.
        if ( !StrEqual( szPrevMapName, szMapName, false ) )
        {
            strcopy( szCurSafeMap, sizeof( szCurSafeMap ), szMapName );
            SafeMapName( szCurSafeMap, sizeof( szCurSafeMap ) );
            
            
            // New map, save the old one
            if ( kv != null )
            {
                SaveFiles( kv, runs, szCurSafeMap );
            }
            
            delete kv;
            delete runs;

            
            
            kv = new KeyValues( "Zones" );
            runs = new ArrayList( 1 ); // Save the run id
            zoneid = 1;
            
            ++nMaps;
        }
        
        strcopy( szPrevMapName, sizeof( szPrevMapName ), szMapName );
        
        
        szZoneName[0] = 0;
        
        bool bIsStartZone = zonetype == 1 || zonetype == 5;
        
        switch ( zonetype )
        {
            case 1 : // Start
            {
                strcopy( szZoneName, sizeof( szZoneName ), "Start" );
            }
            case 2 : // End
            {
                strcopy( szZoneName, sizeof( szZoneName ), "End" );
            }
            case 3 : // Stage
            {
                strcopy( szZoneName, sizeof( szZoneName ), "Stage" );
            }
            case 4 : // Checkpoint
            {
                strcopy( szZoneName, sizeof( szZoneName ), "Checkpoint" );
            }
            case 5 : // Start Speed
            {
                strcopy( szZoneName, sizeof( szZoneName ), "Start" );
            }
            case 6 : // TeleToStart
            {
                strcopy( szZoneName, sizeof( szZoneName ), "Block" );
            }
            case 7 : // Validator
            {
                strcopy( szZoneName, sizeof( szZoneName ), "Validator" );
            }
            case 8 : // Checker
            {
                PrintToServer( "Ignoring map's %s Checker zone!", szCurSafeMap );
            }
            case 9 : // No Pause
            {
                PrintToServer( "Ignoring map's %s No Pause zone!", szCurSafeMap );
            }
            case 0 : // Stop
            {
                strcopy( szZoneName, sizeof( szZoneName ), "Block" );
            }
            default :
            {
                PrintToServer( "Unaccounted zone type %i (group: %i)!!", zonetype, zonegroup );
            }
        }
        
        if ( szZoneName[0] == 0 )
            continue;
        
        
        // We might have a zone with the same name, find a free one
        int j = 2;
        while ( kv.JumpToKey( szZoneName, false ) )
        {
            kv.GoBack();
            
            Format( szZoneName, sizeof( szZoneName ), "%s (%i)", szZoneName, j++ );
        }
        
        kv.JumpToKey( szZoneName, true );
        
        
        kv.SetNum( "id", zoneid );
        
        
        
        // Look, I can understand making poor design choices, but how the fuck can you make
        // a plugin like ckSurf without having defined the ZONETYPES ANYWHERE
        // You have to memorize that shit, wtf.
        
        // Zone group 0:
        // 1 = Start
        // 2 = End
        // 3 = Stage
        // 4 = Checkpoint
        // 5 = Start Speed
        
        // Zone group 1:
        // Same but for bonus
        
        // Zone group 2:
        // 6 = TeleToStart
        // 7 = Validator
        // 8 = Checker
        // 0 = Stop
        // 9 = No Pause
        
        int runid = -1;
        if ( zonegroup < 2 )
            runid = zonegroup == 0 ? MAIN_RUN_ID : (MAIN_RUN_ID+1);
        
        
        // If we don't have this run id yet, record it.
        if ( runid != -1 && bIsStartZone )
        {
            bool bHasRunId = false;
            for ( i = 0; i < runs.Length; i++ )
            {
                if ( runs.Get( i, 0 ) == runid )
                    bHasRunId = true;
            }
            
            if ( !bHasRunId )
            {
                any rundata[1];
                rundata[0] = runid;
                
                runs.PushArray( rundata );
            }
        }
        
        
        // Translate from their types to ours
        switch ( zonetype )
        {
            case 1 : // Start
            {
                kv.SetNum( "run_id", runid );
                kv.SetString( "type", "start" );
            }
            case 2 : // End
            {
                kv.SetNum( "run_id", runid );
                kv.SetString( "type", "end" );
            }
            case 3 : // Stage
            {
                kv.SetNum( "run_id", runid );
                kv.SetString( "type", "stage" );
            }
            case 4 : // Checkpoint
            {
                kv.SetNum( "run_id", runid );
                kv.SetString( "type", "checkpoint" );
            }
            case 5 : // Start Speed
            {
                kv.SetNum( "run_id", runid );
                kv.SetString( "type", "start" );
            }
            case 6 : // TeleToStart
            {
                kv.SetString( "type", "block" );
            }
            case 7 : // Validator
            {
                kv.SetNum( "run_id", runid );
                kv.SetString( "type", "validator" );
            }
            case 0 : // Stop
            {
                kv.SetString( "type", "block" );
            }
        }
        
        
        FormatEx( szCoords, sizeof( szCoords ), "%.0f %.0f %.0f", mins[0], mins[1], mins[2] );
        kv.SetString( "mins", szCoords );
        FormatEx( szCoords, sizeof( szCoords ), "%.0f %.0f %.0f", maxs[0], maxs[1], maxs[2] );
        kv.SetString( "maxs", szCoords );
        
        
        kv.GoBack();
        
        ++zoneid;
        
        ++nZones;
    }
    
    if ( kv != null )
    {
        SaveFiles( kv, runs, szCurSafeMap );
    }
    
    delete kv;
    delete runs;
    
    
    LogMessage( INF_CON_PRE..."Done transferring %i zones from %i maps.", nZones, nMaps );
}

// We don't REALLY need these and I don't think they are ever used in ck???
/*
stock void TransferZoneTelePos( Handle db )
{
    LogMessage( INF_CON_PRE..."Beginning to transfer ckSurf stage teleport positions to Influx..." );
    
    
    if ( db == null )
        db = GetDB();
    
    
    SQL_TQuery(
        db,
        Thrd_ZoneTelePos,
        "SELECT mapname,zonegroup,stage,ang_y,pos_x,pos_y,pos_z FROM ck_spawnlocations ORDER BY mapname,stage ASC",
        _, DBPrio_High );
}

public void Thrd_ZoneTelePos( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "transferring zone tele pos data" );
        return;
    }
    
    if ( !SQL_GetRowCount( res ) )
    {
        LogMessage( INF_CON_PRE..."No rows were received. Either there is nothing there or you haven't connected to the correct database." );
        return;
    }
    
    
    decl String:szPathRun[PLATFORM_MAX_PATH];
    decl String:szPathZone[PLATFORM_MAX_PATH];
    decl String:szCurSafeMap[256];
    decl String:szPrevMapName[256];
    szPrevMapName[0] = 0;
    
    decl String:szMapName[256];
    int zonegroup;
    int stage;
    float pos[3];
    float yaw;
    
    int nTelePos = 0;
    int nMaps = 0;
    
    int i;
    
    PrintToServer( INF_CON_PRE..."Reading tele pos query results..." );
    
    
    KeyValues runkv = null;
    KeyValues zonekv = null;

    while ( SQL_FetchRow( res ) )
    {
        SQL_FetchString( res, 0, szMapName, sizeof( szMapName ) );
        zonegroup = SQL_FetchInt( res, 1 );
        stage = SQL_FetchInt( res, 2 );
        
        yaw = SQL_FetchFloat( res, 3 );
        
        for ( i = 0; i < 3; i++ )
            pos[i] = SQL_FetchFloat( res, 4 + i );
        
        
        // We've ordered it by map, so start a new one each map.
        if ( !StrEqual( szPrevMapName, szMapName, false ) )
        {
            strcopy( szCurSafeMap, sizeof( szCurSafeMap ), szMapName );
            SafeMapName( szCurSafeMap, sizeof( szCurSafeMap ) );
            
            
            if ( runkv != null )
            {
                runkv.ExportToFile( szPathRun );
            }
            
            if ( zonekv != null )
            {
                zonekv.ExportToFile( szPathZone );
            }
            
            delete runkv;
            delete zonekv;
            
            // Load run kv
            runkv = new KeyValues( "Runs" );
            BuildPath( Path_SM, szPathRun, sizeof( szPathRun ), "influxruns/%s.ini", szCurSafeMap );
            if ( !runkv.ImportFromFile( szPathRun ) )
            {
                delete runkv;
            }
            
            
            // Load zone kv
            zonekv = new KeyValues( "Zones" );
            BuildPath( Path_SM, szPathZone, sizeof( szPathZone ), "influxzones/%s.ini", szCurSafeMap );
            if ( !zonekv.ImportFromFile( szPathZone ) )
            {
                delete zonekv;
            }
            
            
            
            ++nMaps;
        }
        
        
        
        int runid = zonegroup == 0 ? MAIN_RUN_ID : (MAIN_RUN_ID+1);
        
        
        // This is the first stage. ie. start tele pos
        if ( stage <= 1 )
        {
            // We're in the run kv
            if ( runkv && runkv.GotoFirstSubKey() )
            {
                do
                {
                    // Find the correct run
                    
                    if ( runkv.GetNum( "run_id" ) == runid )
                    {
                        runkv.SetVector( "telepos", pos );
                        runkv.SetFloat( "teleyaw", yaw );
                        
                        ++nTelePos;
                        break;
                    }
                }
                while( runkv.GotoNextKey() );
                
                runkv.Rewind();
            }
        }
        else
        {
            if ( zonekv && zonekv.GotoFirstSubKey() )
            {
                char temp[64];
                do
                {
                    // Find the correct zone
                    
                    zonekv.GetString( "type", temp, sizeof( temp ) );
                    if ( !StrEqual( temp, "stage", false ) )
                        continue;
                    
                    if ( zonekv.GetNum( "run_id" ) != runid )
                        continue;
                    
                    if ( zonekv.GetNum( "stage_num" ) != stage )
                        continue;
                    
                    
                    zonekv.SetVector( "stage_telepos", pos );
                    zonekv.SetFloat( "stage_teleyaw", yaw );
                    
                    ++nTelePos;
                    break;
                }
                while( zonekv.GotoNextKey() );
                
                zonekv.Rewind();
            }
        }
    }
    
    
    LogMessage( INF_CON_PRE..."Done transferring %i tele positions from %i maps.", nTelePos, nMaps );
}
 */

stock void SafeMapName( char[] sz, int len )
{
    StringToLower( sz );
    
    // GetMapDisplayName seems to require that the map is in mapcycle file(?)
    // I never got it to work. This is why we're doing this.
    int lastpos = -1;
    
    int start = 0;
    int pos = -1;
    
    while ( (pos = FindCharInString( sz[start], '/' )) != -1 )
    {
        lastpos = pos + start + 1;
        
        start += pos + 1;
    }
    
    if ( lastpos != -1 && sz[lastpos] != '\0' )
    {
        strcopy( sz, len, sz[lastpos] );
    }
}
