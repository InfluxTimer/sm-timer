#include <sourcemod>

#include <influx/core>
#include <influx/zones>
#include <influx/zones_stage>

#undef REQUIRE_PLUGIN
#include <influx/zones_checkpoint>


#define DEBUG
//#define DEBUG_ZONE
#define DEBUG_ZONE_ENTER


enum
{
    STAGEZONE_ID = 0,
    
    STAGEZONE_RUN_ID,
    
    STAGEZONE_NUM,
    
    STAGEZONE_ENTREF,
    
    STAGEZONE_SIZE
};


enum
{
    STAGE_RUN_ID = 0,
    
    STAGE_NUM,
    
    STAGE_SIZE
};


ArrayList g_hStages;
ArrayList g_hStageZones;


int g_iStage[INF_MAXPLAYERS];
//int g_cache_nStages[INF_MAXPLAYERS];

int g_iBuildingNum[INF_MAXPLAYERS];


ConVar g_ConVar_ActAsCP;
ConVar g_ConVar_DisplayType;
ConVar g_ConVar_DisplayOnlyMain;


bool g_bLib_Zones_CP;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Zones | Stage",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_ZONES_STAGE );
    
    
    // NATIVES
    CreateNative( "Influx_ShouldDisplayStages", Native_ShouldDisplayStages );
    
    
    CreateNative( "Influx_GetClientStage", Native_GetClientStage );
    CreateNative( "Influx_GetClientStageCount", Native_GetClientStageCount );
    
    CreateNative( "Influx_GetRunStageCount", Native_GetRunStageCount );
}

public void OnPluginStart()
{
    g_hStages = new ArrayList( STAGE_SIZE );
    g_hStageZones = new ArrayList( STAGEZONE_SIZE );
    
    
    // CONVARS
    g_ConVar_ActAsCP = CreateConVar( "influx_stage_actascp", "1", "Stage zones act as checkpoints if checkpoints module is loaded.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    g_ConVar_DisplayType = CreateConVar( "influx_stage_displaytype", "2", "0 = Don't display stages, 1 = Display stages if non-linear, 2 = Display all stages", FCVAR_NOTIFY, true, 0.0, true, 2.0 );
    g_ConVar_DisplayOnlyMain = CreateConVar( "influx_stage_displayonlymain", "1", "", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    // LIBRARIES
    g_bLib_Zones_CP = LibraryExists( INFLUX_LIB_ZONES_CP );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_ZONES_CP ) ) g_bLib_Zones_CP = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_ZONES_CP ) ) g_bLib_Zones_CP = false;
}

public void OnClientPutInServer( int client )
{
    g_iStage[client] = 1;
    //g_cache_nStages[client] = 0;
    
    g_iBuildingNum[client] = 0;
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    g_iStage[client] = 1;
}

public void Influx_OnTimerResetPost( int client )
{
    g_iStage[client] = 1;
}

public void Influx_OnPreRunLoad()
{
    g_hStages.Clear();
}

public Action Influx_OnZoneLoad( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_STAGE ) return Plugin_Continue;
    
    
    int runid = kv.GetNum( "run_id", -1 );
    if ( runid < 1 ) return Plugin_Stop;
    
    
    int stagenum = kv.GetNum( "stage_num", -1 );
    if ( stagenum < 2 ) return Plugin_Stop;
    
    
    AddStageZone( zoneid, runid, stagenum );
    
    AddStage( runid, stagenum );
    
    
    return Plugin_Handled;
}

public Action Influx_OnZoneSave( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_STAGE ) return Plugin_Continue;
    
    
    int index = FindStageZoneById( zoneid );
    if ( index == -1 ) return Plugin_Stop;
    
    
    kv.SetNum( "run_id", g_hStageZones.Get( index, STAGEZONE_RUN_ID ) );
    
    kv.SetNum( "stage_num", g_hStageZones.Get( index, STAGEZONE_NUM ) );
    
    return Plugin_Handled;
}

public void Influx_OnZoneCreated( int client, int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_STAGE ) return;
    
    
    int runid = Influx_GetClientRunId( client );
    if ( runid < 1 ) return;
    
    
    int stagenum = g_iBuildingNum[client];
    if ( stagenum < 2 ) return;
    
    
    
    AddStageZone( zoneid, runid, stagenum );
    AddStage( runid, stagenum );
}

public void Influx_OnZoneSpawned( int zoneid, ZoneType_t zonetype, int ent )
{
    if ( zonetype != ZONETYPE_STAGE ) return;
    
    
    int index = FindStageZoneById( zoneid );
    if ( index == -1 ) return;
    
    
    // Update ent reference.
    g_hStageZones.Set( index, EntIndexToEntRef( ent ), STAGEZONE_ENTREF );
    
    
    SDKHook( ent, SDKHook_StartTouchPost, E_StartTouchPost_Stage );
    
    
    Inf_SetZoneProp( ent, g_hStageZones.Get( index, STAGEZONE_ID ) );
}

public void Influx_OnZoneDeleted( int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_STAGE ) return;
    
    
    RemoveStageById( zoneid );
}

public Action Influx_OnZoneBuildAsk( int client, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_STAGE ) return Plugin_Continue;
    
    
    
    int runid = Influx_GetClientRunId( client );
    
    if ( runid == -1 ) return Plugin_Continue;
    
    
    
    char szDisplay[32];
    char szInfo[32];
    char szRun[MAX_RUN_NAME];
    
    
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    
    
    Menu menu = new Menu( Hndlr_CreateZone_SelectStage );
    menu.SetTitle( "Which stage do you want to create?\nRun: %s\nStages: %i\n ",
        szRun,
        GetRunStageCount( runid ) );
    
    
    
    
    int highest = 1;
    
    int stagenum;
    
    
    int len = g_hStages.Length;
    for( int i = 0; i < len; i++ )
    {
        if ( g_hStages.Get( i, STAGE_RUN_ID ) != runid ) continue;
        
        
        stagenum = g_hStages.Get( i, STAGE_NUM );
        
        if ( stagenum > highest )
        {
            highest = stagenum;
        }
    }
    
    ++highest;
    
    
    // Add highest to the top.
    FormatEx( szInfo, sizeof( szInfo ), "%i", highest );
    FormatEx( szDisplay, sizeof( szDisplay ), "New Stage %i\n ", highest );
    
    menu.AddItem( szInfo, szDisplay );
    
    
    
    // Display them in a sorted order.
    for ( int i = 2; i < highest; i++ )
    {
        FormatEx( szInfo, sizeof( szInfo ), "%i", i );
        FormatEx( szDisplay, sizeof( szDisplay ), "Stage %i", i );
        
        menu.AddItem( szInfo, szDisplay );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Stop;
}

public int Hndlr_CreateZone_SelectStage( Menu oldmenu, MenuAction action, int client, int index )
{
    MENU_HANDLE( oldmenu, action )
    
    
    char szInfo[16];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int runid = Influx_GetClientRunId( client );
    if ( runid < 1 ) return 0;
    
    
    int stagenum = StringToInt( szInfo );
    if ( stagenum < 2 ) return 0;
    
    
    if ( FindStageByNum( runid, stagenum ) != -1 )
    {
        Menu menu = new Menu( Hndlr_CreateZone_SelectMethod );
        
        menu.SetTitle( "That stage already exists!\n " );
        
        menu.AddItem( szInfo, "Create a new instance (keep both)" );
        menu.AddItem( szInfo, "Replace existing one(s)\n " );
        menu.AddItem( "", "Cancel" );
        
        menu.ExitButton = false;
        
        menu.Display( client, MENU_TIME_FOREVER );
    }
    else
    {
        StartToBuild( client, stagenum );
    }
    
    return 0;
}

public int Hndlr_CreateZone_SelectMethod( Menu oldmenu, MenuAction action, int client, int index )
{
    MENU_HANDLE( oldmenu, action )
    
    
    char szInfo[16];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int runid = Influx_GetClientRunId( client );
    if ( runid < 1 ) return 0;
    
    
    int stagenum = StringToInt( szInfo );
    if ( stagenum < 2 ) return 0;
    
    
    switch ( index )
    {
        case 0 : // Keep both
        {
            StartToBuild( client, stagenum );
        }
        case 1 : // Replace existing ones
        {
            int len = g_hStageZones.Length;
            for ( int i = 0; i < len; i++ )
            {
                if ( g_hStageZones.Get( i, STAGEZONE_RUN_ID ) != runid ) continue;
                
                if ( g_hStageZones.Get( i, STAGEZONE_NUM ) != stagenum ) continue;
                
                
                int zoneid = g_hStageZones.Get( i, STAGEZONE_ID );
                
                Influx_DeleteZone( zoneid );
                
                
                --i;
                len = g_hStageZones.Length;
            }
            
            StartToBuild( client, stagenum );
        }
    }
    
    return 0;
}

stock void StartToBuild( int client, int stagenum )
{
    g_iBuildingNum[client] = stagenum;
    
    
    char szName[MAX_ZONE_NAME];
    char szRun[MAX_RUN_NAME];
    
    Influx_GetRunName( Influx_GetClientRunId( client ), szRun, sizeof( szRun ) );
    
    FormatEx( szName, sizeof( szName ), "%s Stage %i", szRun, stagenum );
    
    
    Influx_BuildZone( client, ZONETYPE_STAGE, szName );
}

public void E_StartTouchPost_Stage( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
    int zoneid = Inf_GetZoneProp( ent );
    
#if defined DEBUG_ZONE
    PrintToServer( INF_DEBUG_PRE..."Player %i touched stage (id: %i | ent: %i)", activator, zoneid, ent );
#endif
    
    int zindex = FindStageZoneById( zoneid );
    if ( zindex == -1 ) return;
    
    
    int runid = g_hStageZones.Get( zindex, STAGEZONE_RUN_ID );
    if ( runid != Influx_GetClientRunId( activator ) ) return;
    
    
    int stagenum = g_hStageZones.Get( zindex, STAGEZONE_NUM );
    
    // That stage doesn't exist!
    if ( FindStageByNum( runid, stagenum ) == -1 ) return;
    
    
#if defined DEBUG_ZONE_ENTER
    if ( g_iStage[activator] != stagenum )
    {
        PrintToServer( INF_DEBUG_PRE..."Entered stage %i!", stagenum );
    }
#endif
    
    g_iStage[activator] = stagenum;
    
    if ( g_bLib_Zones_CP && g_ConVar_ActAsCP.BoolValue )
    {
        Influx_SaveClientCP( activator, stagenum - 1 );
    }
}

stock int AddStageZone( int zoneid, int runid, int stagenum )
{
    int index = FindStageZoneById( zoneid );
    if ( index != -1 ) return index;
    
    
    decl data[STAGEZONE_SIZE];
    
    data[STAGEZONE_ID] = zoneid;
    
    data[STAGEZONE_RUN_ID] = runid;
    
    data[STAGEZONE_NUM] = stagenum;
    
    data[STAGEZONE_ENTREF] = INVALID_ENT_REFERENCE;
    
    return g_hStageZones.PushArray( data );
}

stock void RemoveStageById( int zoneid )
{
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Removing stage with id %i!", zoneid );
#endif

    int index;
    
    
    index = FindStageZoneById( zoneid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Couldn't find stage zone with id %i!", zoneid )
        return;
    }
    
    
    int runid = g_hStageZones.Get( index, STAGEZONE_RUN_ID );
    int stagenum = g_hStageZones.Get( index, STAGEZONE_NUM );
    
    
    g_hStageZones.Erase( index );
    
    
    // Check if any other stage zones exist with this run and stage num.
    // If not, delete our stage.
    if ( FindStageZoneByNum( runid, stagenum ) == -1 )
    {
        index = FindStageByNum( runid, stagenum );
        
        if ( index != -1 )
        {
#if defined DEBUG
            PrintToServer( INF_DEBUG_PRE..."Removing stage (Run id: %i | Stage num: %i)", runid, stagenum );
#endif
            g_hStages.Erase( index );
        }
    }
}

stock int AddStage( int runid, int stagenum )
{
    int index;
    
    
    index = FindStageByNum( runid, stagenum );
    if ( index != -1 ) return index;
    
    
    decl data[STAGE_SIZE];
    data[STAGE_RUN_ID] = runid;
    data[STAGE_NUM] = stagenum;
    
    index = g_hStageZones.PushArray( data );
    
    
    if ( g_bLib_Zones_CP && g_ConVar_ActAsCP.BoolValue )
    {
        char szName[MAX_CP_NAME];
        
        FormatEx( szName, sizeof( szName ), "Stage %i", stagenum );
        
        Influx_AddCP( runid, stagenum - 1, szName );
    }
    
    return index;
}

stock int FindStageZoneById( int id )
{
    int len = g_hStages.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hStageZones.Get( i, STAGEZONE_ID ) == id )
        {
            return i;
        }
    }
    
    return -1;
}

stock int GetRunStageCount( int runid )
{
    int num = 0;
    
    int len = g_hStages.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hStages.Get( i, STAGE_RUN_ID ) == runid )
        {
            ++num;
        }
    }
    
    return num;
}

stock int GetRunStageZoneCount( int runid )
{
    int num = 0;
    
    int len = g_hStageZones.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hStageZones.Get( i, STAGEZONE_RUN_ID ) == runid )
        {
            ++num;
        }
    }
    
    return num;
}

stock int FindStageByNum( int runid, int num )
{
    int len = g_hStages.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hStages.Get( i, STAGE_RUN_ID ) != runid ) continue;
        
        if ( g_hStages.Get( i, STAGE_NUM ) == num )
        {
            return i;
        }
    }
    
    return -1;
}

stock int FindStageZoneByNum( int runid, int num )
{
    int len = g_hStageZones.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hStageZones.Get( i, STAGEZONE_RUN_ID ) != runid ) continue;
        
        if ( g_hStageZones.Get( i, STAGEZONE_NUM ) == num )
        {
            return i;
        }
    }
    
    return -1;
}

// NATIVES
public int Native_ShouldDisplayStages( Handle hPlugin, int nParms )
{
    if ( g_ConVar_DisplayType.IntValue == 0 ) return 0;
    
    
    int client = GetNativeCell( 1 );
    
    int runid = Influx_GetClientRunId( client );
    
    
    if ( g_ConVar_DisplayOnlyMain.BoolValue && runid != MAIN_RUN_ID ) return 0;
    
    
    int count = GetRunStageCount( runid );
    
    if ( !count )
    {
        return ( g_ConVar_DisplayType.IntValue == 2 );
    }
    
    return 1;
}

public int Native_GetClientStage( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return g_iStage[client];
}

public int Native_GetClientStageCount( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return GetRunStageCount( Influx_GetClientRunId( client ) );
}

public int Native_GetRunStageCount( Handle hPlugin, int nParms )
{
    int runid = GetNativeCell( 1 );
    
    return GetRunStageCount( runid );
}