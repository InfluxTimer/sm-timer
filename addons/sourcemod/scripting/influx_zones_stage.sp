#include <sourcemod>

#include <influx/core>
#include <influx/zones>
#include <influx/zones_stage>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>

#undef REQUIRE_PLUGIN
#include <influx/help>
#include <influx/zones_checkpoint>


//#define DEBUG
//#define DEBUG_ZONE
//#define DEBUG_ZONE_ENTER


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
    
    STAGE_TELEPOS[3],
    STAGE_TELEYAW,
    
    STAGE_SIZE
};


ArrayList g_hStages;
ArrayList g_hStageZones;


int g_iStage[INF_MAXPLAYERS];
int g_nStages[INF_MAXPLAYERS];

int g_iBuildingNum[INF_MAXPLAYERS];
int g_iBuildingRunId[INF_MAXPLAYERS] = { -1, ... };

bool g_bLeftStageZone[INF_MAXPLAYERS];


ConVar g_ConVar_ActAsCP;
ConVar g_ConVar_DisplayType;
ConVar g_ConVar_DisplayOnlyMain;
ConVar g_ConVar_AllowStageBackTeleport;


bool g_bLib_Zones_CP;


bool g_bLate;


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
    g_bLate = late;
    
    
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
    
    
    // PHRASES
    LoadTranslations( INFLUX_PHRASES );
    
    
    // CONVARS
    g_ConVar_ActAsCP = CreateConVar( "influx_zones_stage_actascp", "1", "Stage zones act as checkpoints if checkpoints module is loaded.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    g_ConVar_AllowStageBackTeleport = CreateConVar( "influx_zones_stage_allowstagebacktele", "1", "Can players use !back/!teleport to go back to stage start?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    g_ConVar_DisplayType = CreateConVar( "influx_zones_stage_displaytype", "2", "0 = Don't display stages, 1 = Display stages if non-linear, 2 = Display all stages", FCVAR_NOTIFY, true, 0.0, true, 2.0 );
    g_ConVar_DisplayOnlyMain = CreateConVar( "influx_zones_stage_displayonlymain", "1", "Only display stage count if player's run is main.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    AutoExecConfig( true, "zones_stage", "influx" );
    
    
    // CMDS
#if defined DEBUG
    RegAdminCmd( "sm_debugprintstages", Cmd_PrintStages, ADMFLAG_ROOT );
    RegAdminCmd( "sm_debugprintstagezones", Cmd_PrintStageZones, ADMFLAG_ROOT );
#endif
    
    RegAdminCmd( "sm_setstagetelepos", Cmd_SetStageTelePos, ADMFLAG_ROOT );
    
    RegConsoleCmd( "sm_stage", Cmd_StageSelect );
    RegConsoleCmd( "sm_s", Cmd_StageSelect );
    
    RegConsoleCmd( "sm_back", Cmd_Back );
    RegConsoleCmd( "sm_teleport", Cmd_Back );
    
    
    // LIBRARIES
    g_bLib_Zones_CP = LibraryExists( INFLUX_LIB_ZONES_CP );
    
    
    if ( g_bLate )
    {
        // If core has already loaded runs
        // register runs ourselves.
        if ( Influx_HasLoadedRuns() )
        {
            Influx_OnPreRunLoad();
            
            ArrayList runs = Influx_GetRunsArray();
            int len = runs.Length;
            
            for ( int i = 0; i < len; i++ )
            {
                Influx_OnRunCreated( runs.Get( i, RUN_ID ) );
            }
        }
    }
}

public void OnAllPluginsLoaded()
{
    AddZoneType();
}

public void Influx_OnRequestZoneTypes()
{
    AddZoneType();
}

stock void AddZoneType()
{
    if ( !Influx_RegZoneType( ZONETYPE_STAGE, "Stage", "stage", false ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't register zone type!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveZoneType( ZONETYPE_STAGE );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_ZONES_CP ) ) g_bLib_Zones_CP = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_ZONES_CP ) ) g_bLib_Zones_CP = false;
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "setstagetelepos <num>", "Set stage teleport position.", true );
}

public void OnClientPutInServer( int client )
{
    g_iStage[client] = 1;
    g_nStages[client] = 0;
    
    g_iBuildingNum[client] = 0;
    
    g_bLeftStageZone[client] = false;
}

public Action Influx_OnSearchTelePos( float pos[3], float &yaw, int runid, int telepostype )
{
    // Return stage tele pos
    if ( telepostype >= TELEPOSTYPE_STAGE_START && telepostype <= TELEPOSTYPE_STAGE_END )
    {
        int stagenum = telepostype - TELEPOSTYPE_STAGE_START + 2;
        
        int index = FindStageByNum( runid, stagenum );
        
        if ( index == -1 )
        {
            return Plugin_Continue;
        }
        
        
        GetStageTelePos( index, pos );
        
        yaw = GetStageTeleYaw( index );
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    g_iStage[client] = 1;
    
    Influx_OnClientStatusChanged( client );
}

public void Influx_OnTimerResetPost( int client )
{
    g_iStage[client] = 1;
    
    Influx_OnClientStatusChanged( client );
}

public void Influx_OnClientStatusChanged( int client )
{
    g_nStages[client] = GetRunStageCount( Influx_GetClientRunId( client ) );
}

public void Influx_OnPreRunLoad()
{
    g_hStages.Clear();
    g_hStageZones.Clear();
}

public void Influx_OnRunCreated( int runid )
{
    // Update stages that don't have a run to use the newly created run.
    int len;
    
    len = g_hStages.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hStages.Get( i, STAGE_RUN_ID ) != -1 ) continue;
        
        
        g_hStages.Set( i, runid, STAGE_RUN_ID );
    }
    
    
    char szRun[32];
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    
    char szName[32];
    
    
    len = g_hStageZones.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hStageZones.Get( i, STAGEZONE_RUN_ID ) != -1 ) continue;
        
        
        g_hStageZones.Set( i, runid, STAGEZONE_RUN_ID );
        
        FormatEx( szName, sizeof( szName ), "%s Stage %i", szRun, g_hStageZones.Get( i, STAGEZONE_NUM ) );
        
        Influx_SetZoneName( g_hStageZones.Get( i, STAGEZONE_ID ), szName );
    }
}

public Action Influx_OnZoneLoad( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_STAGE ) return Plugin_Continue;
    
    
    int runid = kv.GetNum( "run_id", -1 );
    if ( runid < 1 ) return Plugin_Stop;
    
    
    int stagenum = kv.GetNum( "stage_num", -1 );
    if ( stagenum < 2 ) return Plugin_Stop;
    
    
    float pos[3];
    kv.GetVector( "stage_telepos", pos, INVALID_TELEPOS );
    
    float yaw = kv.GetFloat( "stage_teleyaw", 0.0 );
    
    
    AddStageZone( zoneid, runid, stagenum );
    
    AddStage( runid, stagenum, pos, yaw );
    
    
    return Plugin_Handled;
}

public Action Influx_OnZoneSave( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_STAGE ) return Plugin_Continue;
    
    
    int index = FindStageZoneById( zoneid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Stage zone (id: %i) is not registered with the plugin! Cannot save!",
            zoneid );
        return Plugin_Stop;
    }
    
    int runid = g_hStageZones.Get( index, STAGEZONE_RUN_ID );
    
    int stagenum = g_hStageZones.Get( index, STAGEZONE_NUM );
    
    kv.SetNum( "run_id", runid );
    
    kv.SetNum( "stage_num", stagenum );
    
    
    index = FindStageByNum( runid, stagenum );
    
    if ( index != -1 )
    {
        float pos[3];
        GetStageTelePos( index, pos );
        
        float yaw = GetStageTeleYaw( index );
        
        
        kv.SetVector( "stage_telepos", pos );
        kv.SetFloat( "stage_teleyaw", yaw );
    }
    
    return Plugin_Handled;
}

public void Influx_OnZoneCreated( int client, int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_STAGE ) return;
    
    
    int runid = g_iBuildingRunId[client];
    
    
    int stagenum = g_iBuildingNum[client];
    if ( stagenum < 2 )
    {
        LogError( INF_CON_PRE..."Stage zone (id: %i) cannot be properly initialized because stage number %i is invalid!",
            zoneid,
            stagenum );
        return;
    }
    
    AddStageZone( zoneid, runid, stagenum );
    
    
    if ( FindStageByNum( runid, stagenum ) == -1 )
    {
        float mins[3];
        float maxs[3];
        
        Influx_GetZoneMinsMaxs( zoneid, mins, maxs );
        
        
        float pos[3];
        float yaw;
        
        if ( !Inf_FindTelePos( mins, maxs, pos, yaw ) )
        {
            Inf_TelePosFromMinsMaxs( mins, maxs, pos );
            yaw = 0.0;
        }
        
        AddStage( runid, stagenum, pos, yaw );
    }
}

public void Influx_OnZoneSpawned( int zoneid, ZoneType_t zonetype, int ent )
{
    if ( zonetype != ZONETYPE_STAGE ) return;
    
    
    int index = FindStageZoneById( zoneid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Stage zone (id: %i) is not registered with the plugin! Cannot register hooks!",
            zoneid );
        return;
    }
    
    // Update ent reference.
    g_hStageZones.Set( index, EntIndexToEntRef( ent ), STAGEZONE_ENTREF );
    
    
    SDKHook( ent, SDKHook_StartTouchPost, E_StartTouchPost_Stage );
    SDKHook( ent, SDKHook_EndTouchPost, E_EndTouchPost_Stage );
    
    
    Inf_SetZoneProp( ent, zoneid );
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
    if ( action == MenuAction_End )
    {
        delete oldmenu;
        return 0;
    }
    
    Influx_SetDrawBuildingSprite( client, false );
    
    if ( action != MenuAction_Select ) return 0;
    
    
    char szInfo[16];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int stagenum = StringToInt( szInfo );
    if ( stagenum < 2 ) return 0;
    
    
    int runid = Influx_GetClientRunId( client );
    
    
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
    
    
    int stagenum = StringToInt( szInfo );
    if ( stagenum < 2 ) return 0;
    
    
    int runid = Influx_GetClientRunId( client );
    
    
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
                
                if ( Influx_DeleteZone( zoneid ) || RemoveStageById( zoneid ) )
                {
                    --i;
                    len = g_hStageZones.Length;
                }
            }
            
            StartToBuild( client, stagenum );
        }
    }
    
    return 0;
}

stock void StartToBuild( int client, int stagenum )
{
    int runid = Influx_GetClientRunId( client );
    
    g_iBuildingNum[client] = stagenum;
    g_iBuildingRunId[client] = runid;
    
    
    char szName[MAX_ZONE_NAME];
    char szRun[MAX_RUN_NAME];
    
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    
    FormatEx( szName, sizeof( szName ), "%s Stage %i", szRun, stagenum );
    
    
    Influx_BuildZone( client, ZONETYPE_STAGE, szName );
    
    
    Inf_OpenZoneMenu( client );
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
    
    g_bLeftStageZone[activator] = false;
    
    
    if ( g_bLib_Zones_CP && g_ConVar_ActAsCP.BoolValue )
    {
        Influx_SaveClientCP( activator, stagenum - 1 );
    }
}

public void E_EndTouchPost_Stage( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
    int zoneid = Inf_GetZoneProp( ent );
    
    
    int zindex = FindStageZoneById( zoneid );
    if ( zindex == -1 )
        return;
    
    
    int runid = g_hStageZones.Get( zindex, STAGEZONE_RUN_ID );
    if ( runid != Influx_GetClientRunId( activator ) )
        return;
    
    
    int stagenum = g_hStageZones.Get( zindex, STAGEZONE_NUM );
    
    if ( g_iStage[activator] != stagenum )
        return;
    
    
    g_bLeftStageZone[activator] = true;
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

stock bool RemoveStageById( int zoneid )
{
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Removing stage with id %i!", zoneid );
#endif

    int index;
    
    
    index = FindStageZoneById( zoneid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Couldn't find stage zone with id %i to delete!", zoneid );
        return false;
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
            
            
            UpdateClients( runid, stagenum );
        }
    }
    
    return true;
}

stock int AddStage( int runid, int stagenum, const float pos[3], float yaw )
{
    int index;
    
    
    index = FindStageByNum( runid, stagenum );
    if ( index != -1 ) return index;
    
    
    decl data[STAGE_SIZE];
    data[STAGE_RUN_ID] = runid;
    data[STAGE_NUM] = stagenum;
    
    index = g_hStages.PushArray( data );
    
    
    SetStageTelePos( index, pos );
    SetStageTeleYaw( index, yaw );
    
    if ( g_bLib_Zones_CP && g_ConVar_ActAsCP.BoolValue )
    {
        char szName[MAX_CP_NAME];
        
        FormatEx( szName, sizeof( szName ), "Stage %i", stagenum );
        
        Influx_AddCP( runid, stagenum - 1, szName );
    }
    
    UpdateClients();
    
    return index;
}

// When stage has been added/removed.
stock void UpdateClients( int removedrunid = 0, int removedstagenum = 0 )
{
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame( i ) && !IsFakeClient( i ) )
        {
            Influx_OnClientStatusChanged( i );
            
            if ( Influx_GetClientRunId( i ) == removedrunid && g_iStage[i] == removedstagenum )
            {
                --g_iStage[i];
            }
        }
    }
}

stock int FindStageZoneById( int id )
{
    int len = g_hStageZones.Length;
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
    // There's always at least one stage, duh.
    int num = 1;
    
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

stock int FindStageById( int runid, int startindex = -1 )
{
    ++startindex;
    if ( startindex < 0 ) startindex = 0;
    
    int len = g_hStages.Length;
    for ( int i = startindex; i < len; i++ )
    {
        if ( g_hStages.Get( i, STAGE_RUN_ID ) == runid )
        {
            return i;
        }
    }
    
    return -1;
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

stock void TeleportToStage( int client, int stagenum )
{
    int runid = Influx_GetClientRunId( client );
    
    int index = FindStageByNum( runid, stagenum );
    
    if ( index == -1 )
    {
        Influx_PrintToChat( _, client, "%T", "INF_STAGENUMBERNOTEXIST", client, stagenum );
        return;
    }
    
    float pos[3];
    float ang[3];
    
    GetStageTelePos( index, pos );
    
    ang[1] = GetStageTeleYaw( index );
    
    
    // Make sure our teleport location is ok.
    if ( Inf_IsValidTelePos( pos ) )
    {
        ResetStageTelePosByIndex( index, pos, ang[1] );
    }
    
    
    Influx_InvalidateClientRun( client );
    
    TeleportEntity( client, pos, ang, ORIGIN_VECTOR );
}

public Action Cmd_SetStageTelePos( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int stagenum = g_iStage[client];
    
    if ( args )
    {
        char szArg[16];
        GetCmdArgString( szArg, sizeof( szArg ) );
        
        stagenum = StringToInt( szArg );
    }
    
    
    int runid = Influx_GetClientRunId( client );
    
    
    int index = FindStageByNum( runid, stagenum );
    
    if ( index != -1 )
    {
        float pos[3];
        float ang[3];
        
        GetClientAbsOrigin( client, pos );
        GetClientEyeAngles( client, ang );
        
        SetStageTelePos( index, pos );
        SetStageTeleYaw( index, ang[1] );
        
        
        Influx_PrintToChat( _, client, "Set stage {MAINCLR1}%i{CHATCLR} tele position and yaw!", stagenum );
    }
    else
    {
        Influx_PrintToChat( _, client, "%T", "INF_STAGENUMBERNOTEXIST", client, stagenum );
    }
    
    return Plugin_Handled;
}

public Action Cmd_StageSelect( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int stagenum = 1;
    
    
    if ( !args )
    {
        char szDisplay[32];
        char szInfo[32];
        
        int runid = Influx_GetClientRunId( client );
        
        int num = 0;
        
        int highest = 0;
        
        
        Menu menu = new Menu( Hndlr_ChooseStage );
    
        menu.SetTitle( "Stages\n " );
        
        
        int len = g_hStages.Length;
        for ( int i = 0; i < len; i++ )
        {
            if ( g_hStages.Get( i, STAGE_RUN_ID ) != runid ) continue;
            
            
            stagenum = g_hStages.Get( i, STAGE_NUM );
            
            if ( stagenum > highest )
            {
                highest = stagenum;
            }
        }
        
        if ( highest >= 2 )
        {
            menu.AddItem( "1", "Stage 1" );
        }
        
        for ( int i = 2; i <= highest; i++ )
        {
            if ( FindStageByNum( runid, i ) == -1 ) continue;
            
            
            FormatEx( szInfo, sizeof( szInfo ), "%i", i );
            FormatEx( szDisplay, sizeof( szDisplay ), "Stage %i", i );
            
            menu.AddItem( szInfo, szDisplay );
            
            ++num;
        }
        
        if ( !num )
        {
            menu.AddItem( "", "No stages found :(", ITEMDRAW_DISABLED );
        }
        
        menu.Display( client, MENU_TIME_FOREVER );
        
        return Plugin_Handled;
    }
    
    
    char szArg[16];
    GetCmdArgString( szArg, sizeof( szArg ) );
    
    stagenum = StringToInt( szArg );
    
    
    if ( stagenum > 1 )
    {
        TeleportToStage( client, stagenum );
    }
    else
    {
        Influx_TeleportToStart( client );
    }
    
    return Plugin_Handled;
}

public int Hndlr_ChooseStage( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int stagenum = StringToInt( szInfo );
    
    if ( stagenum > 1 )
    {
        TeleportToStage( client, stagenum );
    }
    else
    {
        Influx_TeleportToStart( client );
    }
    
    
    return 0;
}

public Action Cmd_Back( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    // Not allowed?
    if ( g_ConVar_AllowStageBackTeleport.IntValue == 0 )
        return Plugin_Handled;
    
    
    if ( Influx_GetClientState( client ) != STATE_RUNNING )
    {
        Influx_PrintToChat( _, client, "%T", "INF_MUSTBERUNNING", client );
        return Plugin_Handled;
    }
    
    
    // Go back to start.
    if ( g_iStage[client] <= 1 )
    {
        Influx_TeleportToStart( client, false );
        return Plugin_Handled;
    }
    
    
    if ( !g_bLeftStageZone[client] )
    {
        Influx_PrintToChat( _, client, "%T", "INF_LEAVEZONEFIRST", client );
        return Plugin_Handled;
    }
    
    
    int sindex = FindStageByNum( Influx_GetClientRunId( client ), g_iStage[client] );
    if ( sindex != -1 )
    {
        float pos[3];
        float ang[3];
        GetStageTelePos( sindex, pos );
        ang[1] = GetStageTeleYaw( sindex );
        
        TeleportEntity( client, pos, ang, ORIGIN_VECTOR );
    }
    
    return Plugin_Handled;
}

stock void GetStageTelePos( int index, float out[3] )
{
    if ( index == -1 ) return;
    
    
    for ( int i = 0; i < 3; i++ )
    {
        out[i] = view_as<float>( g_hStages.Get( index, STAGE_TELEPOS + i ) );
    }
}

stock void SetStageTelePos( int index, const float pos[3] )
{
    if ( index == -1 ) return;
    
    
    for ( int i = 0; i < 3; i++ )
    {
        g_hStages.Set( index, pos[i], STAGE_TELEPOS + i );
    }
}

stock float GetStageTeleYaw( int index )
{
    if ( index == -1 ) return 0.0;
    
    
    return view_as<float>( g_hStages.Get( index, STAGE_TELEYAW ) );
}

stock void SetStageTeleYaw( int index, float yaw )
{
    if ( index == -1 ) return;
    
    
    g_hStages.Set( index, yaw, STAGE_TELEYAW );
}

stock void ResetStageTelePosByIndex( int istage, float pos[3], float &yaw )
{
    int istagezone = FindStageZoneByNum( g_hStages.Get( istage, STAGE_RUN_ID ), g_hStages.Get( istage, STAGE_NUM ) );
    if ( istagezone == -1 )
        return;
    
    
    float mins[3], maxs[3];
    Influx_GetZoneMinsMaxs( g_hStageZones.Get( istagezone, STAGEZONE_ID ), mins, maxs );
    
    if ( !Inf_FindTelePos( mins, maxs, pos, yaw ) )
    {
        Inf_TelePosFromMinsMaxs( mins, maxs, pos );
    }
    else
    {
        SetStageTeleYaw( istage, yaw );
    }
    
    SetStageTelePos( istage, pos );
}

public Action Cmd_PrintStageZones( int client, int args )
{
    for ( int i = 0; i < g_hStageZones.Length; i++ )
    {
        PrintToServer( INF_DEBUG_PRE..."Stage Id: %i | Stage %i | Run Id: %i", g_hStageZones.Get( i, STAGEZONE_ID ), g_hStageZones.Get( i, STAGEZONE_NUM ), g_hStageZones.Get( i, STAGEZONE_RUN_ID ) );
    }
    
    return Plugin_Handled;
}

public Action Cmd_PrintStages( int client, int args )
{
    for ( int i = 0; i < g_hStages.Length; i++ )
    {
        PrintToServer( INF_DEBUG_PRE..."Stage %i | Run Id: %i", g_hStages.Get( i, STAGE_NUM ), g_hStages.Get( i, STAGE_RUN_ID ) );
    }
    
    return Plugin_Handled;
}

// NATIVES
public int Native_ShouldDisplayStages( Handle hPlugin, int nParms )
{
    if ( g_ConVar_DisplayType.IntValue == 0 ) return 0;
    
    
    int client = GetNativeCell( 1 );
    
    int runid = Influx_GetClientRunId( client );
    
    
    if ( g_ConVar_DisplayOnlyMain.BoolValue && runid != MAIN_RUN_ID ) return 0;
    
    
    if ( g_nStages[client] < 2 )
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
    
    return g_nStages[client];
}

public int Native_GetRunStageCount( Handle hPlugin, int nParms )
{
    int runid = GetNativeCell( 1 );
    
    return GetRunStageCount( runid );
}