#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/zones>
#include <influx/zones_checkpoint>

#include <msharedutil/misc>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <influx/recordsmenu>
#include <influx/help>


// Uncomment this to test out SQL performance on map start.
//#define DISABLE_CREATE_SQL_TABLES                 bool _bUseless = true; if ( _bUseless ) return;


//#define DEBUG_ADDS
//#define DEBUG_ZONE
//#define DEBUG_INSERTREC
//#define DEBUG_DB
//#define DEBUG_SETS
//#define DEBUG_CMD
//#define DEBUG_INSERTCP



#define INF_PRIVCOM_REMOVECPRECORDS     "sm_inf_removecprecords"


enum
{
    CPZONE_ID = 0,
    
    CPZONE_RUN_ID,
    
    CPZONE_NUM,
    
    CPZONE_ENTREF,
    
    CPZONE_SIZE
};

enum
{
    CP_NAME[MAX_CP_NAME_CELL] = 0,
    
    CP_NUM,
    
    CP_RUN_ID,
    
    CP_BESTTIMES[MAX_MODES * MAX_STYLES],
    CP_BESTTIMES_UID[MAX_MODES * MAX_STYLES],
    //CP_BESTTIMES_NAME[MAX_MODES * MAX_STYLES * MAX_BEST_NAME_CELL],
    
    CP_RECTIMES[MAX_MODES * MAX_STYLES],
    CP_RECTIMES_UID[MAX_MODES * MAX_STYLES],
    
    CP_CLIENTTIMES[MAX_MODES * MAX_STYLES * INF_MAXPLAYERS],
    
    CP_SIZE
};

enum
{
    CCP_NUM = 0,
    
    CCP_TIME,
    
    CCP_SIZE
};


ArrayList g_hCPZones;

ArrayList g_hCPs;


int g_iBuildingNum[INF_MAXPLAYERS];
int g_iBuildingRunId[INF_MAXPLAYERS] = { -1, ... };


ArrayList g_hClientCP[INF_MAXPLAYERS];
int g_iClientLatestCP[INF_MAXPLAYERS];


// Cache for hud.
float g_flLastTouch[INF_MAXPLAYERS];
float g_flLastCPTime[INF_MAXPLAYERS] = { INVALID_RUN_TIME, ... };
float g_flLastCPPBTime[INF_MAXPLAYERS] = { INVALID_RUN_TIME, ... };
float g_flLastCPBestTime[INF_MAXPLAYERS] = { INVALID_RUN_TIME, ... };
float g_flLastCPSRTime[INF_MAXPLAYERS] = { INVALID_RUN_TIME, ... };


float g_flLastCmdTime[INF_MAXPLAYERS];



// CONVARS
//ConVar g_ConVar_ReqCPs;


// FORWARDS
Handle g_hForward_OnClientCPSavePost;


// ADMIN MENU
TopMenu g_hTopMenu;


bool g_bLate;


#include "influx_zones_checkpoint/db_sql_queries.sp"
#include "influx_zones_checkpoint/db.sp"
#include "influx_zones_checkpoint/db_cb.sp"
#include "influx_zones_checkpoint/menus.sp"
#include "influx_zones_checkpoint/menus_admin.sp"
#include "influx_zones_checkpoint/menus_hndlrs_admin.sp"


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Zones | Checkpoint",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_ZONES_CP );
    
    
    CreateNative( "Influx_SaveClientCP", Native_SaveClientCP );
    CreateNative( "Influx_AddCP", Native_AddCP );
    
    //CreateNative( "Influx_PrintCPTimes", Native_PrintCPTimes );
    
    CreateNative( "Influx_GetClientLastCP", Native_GetClientLastCP );
    CreateNative( "Influx_GetClientLastCPTouch", Native_GetClientLastCPTouch );
    CreateNative( "Influx_GetClientLastCPTime", Native_GetClientLastCPTime );
    CreateNative( "Influx_GetClientLastCPPBTime", Native_GetClientLastCPPBTime );
    CreateNative( "Influx_GetClientLastCPBestTime", Native_GetClientLastCPBestTime );
    CreateNative( "Influx_GetClientLastCPSRTime", Native_GetClientLastCPSRTime );
    
    
    g_bLate = late;
}

public void OnPluginStart()
{
    g_hCPs = new ArrayList( CP_SIZE );
    
    g_hCPZones = new ArrayList( CPZONE_SIZE );
    
    
    // FORWARDS
    g_hForward_OnClientCPSavePost = CreateGlobalForward( "Influx_OnClientCPSavePost", ET_Ignore, Param_Cell, Param_Cell );
    
    
    // CONVARS
    //g_ConVar_ReqCPs = CreateConVar( "influx_checkpoint_requirecps", "0", "In order to beat the map, player must activate all checkpoints?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );

    
    // PRIVILEGE CMDS
    RegAdminCmd( INF_PRIVCOM_REMOVECPRECORDS, Cmd_Empty, ADMFLAG_ROOT );
    
    
    //CMDS
#if defined DEBUG_CMD
    RegAdminCmd( "sm_debugprintcps", Cmd_PrintCps, ADMFLAG_ROOT );
#endif

    RegConsoleCmd( "sm_cptimes", Cmd_PrintTopCpTimes );
    RegConsoleCmd( "sm_cptime", Cmd_PrintTopCpTimes );
    RegConsoleCmd( "sm_cpwr", Cmd_PrintTopCpTimes );
    RegConsoleCmd( "sm_cptop", Cmd_PrintTopCpTimes );
    RegConsoleCmd( "sm_wrcp", Cmd_PrintTopCpTimes );
    RegConsoleCmd( "sm_topcp", Cmd_PrintTopCpTimes );
    
    
    // MENUS
    RegConsoleCmd( "sm_deletecptimes", Cmd_DeleteCpTimes );
    
    
    if ( g_bLate )
    {
        TopMenu topmenu;
        if ( LibraryExists( "adminmenu" ) && (topmenu = GetAdminTopMenu()) != null )
        {
            OnAdminMenuReady( topmenu );
        }
        
        
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
    
    DB_Init();
}

public void OnAdminMenuReady( Handle hTopMenu )
{
    TopMenu topmenu = TopMenu.FromHandle( hTopMenu );
    
    if ( topmenu == g_hTopMenu )
        return;
    
    
    TopMenuObject res = topmenu.FindCategory( INFLUX_ADMMENU );
    
    if ( res == INVALID_TOPMENUOBJECT )
    {
        return;
    }
    
    
    g_hTopMenu = topmenu;
    g_hTopMenu.AddItem( "sm_deletecptimes", AdmMenu_DeleteCpTimes, res, INF_PRIVCOM_REMOVECPRECORDS, 0 );
}

public void AdmMenu_DeleteCpTimes( TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength )
{
    if ( action == TopMenuAction_DisplayOption )
    {
        strcopy( buffer, maxlength, "CP Times Deletion Menu" );
    }
    else if ( action == TopMenuAction_SelectOption )
    {
        FakeClientCommand( client, "sm_deletecptimes" );
    }
}

public void Influx_OnRequestZoneTypes()
{
    AddZoneType();
}

stock void AddZoneType()
{
    if ( !Influx_RegZoneType( ZONETYPE_CP, "Checkpoint", "checkpoint", false ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't register zone type!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveZoneType( ZONETYPE_CP );
}

public void OnClientPutInServer( int client )
{
    if ( !IsFakeClient( client ) )
    {
        delete g_hClientCP[client];
        
        g_hClientCP[client] = new ArrayList( CCP_SIZE );
        
        
        ResetClientCPTimes( client );
        
        
        g_flLastCmdTime[client] = 0.0;
    }
    
    
    g_iClientLatestCP[client] = 0;
    
    g_flLastTouch[client] = 0.0;
    g_flLastCPBestTime[client] = INVALID_RUN_TIME;
    g_flLastCPSRTime[client] = INVALID_RUN_TIME;
    g_flLastCPTime[client] = INVALID_RUN_TIME;
    
    
    g_iBuildingNum[client] = 0;
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "wrcp/topcp <args>", "Displays all top checkpoint times." );
    Influx_AddHelpCommand( "deletecptimes", "Menu to delete checkpoint times.", true );
}

public void Influx_OnPreRunLoad()
{
    g_hCPZones.Clear();
    g_hCPs.Clear();
}

public void Influx_OnRunCreated( int runid )
{
    // Update checkpoints that don't have a run to use the newly created run.
    int len;
    
    len = g_hCPs.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hCPs.Get( i, CP_RUN_ID ) != -1 ) continue;
        
        
        g_hCPs.Set( i, runid, CP_RUN_ID );
    }
    
    
    char szRun[32];
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    
    char szName[32];
    
    
    len = g_hCPZones.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hCPZones.Get( i, CPZONE_RUN_ID ) != -1 ) continue;
        
        
        g_hCPZones.Set( i, runid, CPZONE_RUN_ID );
        
        
        FormatEx( szName, sizeof( szName ), "%s CP %i", szRun, g_hCPZones.Get( i, CPZONE_NUM ) );
        
        Influx_SetZoneName( g_hCPZones.Get( i, CPZONE_ID ), szName );
    }
}

public void Influx_OnClientIdRetrieved( int client, int uid, bool bNew )
{
    DB_InitClientCPTimes( client );
}

public void Influx_OnMapIdRetrieved( int mapid, bool bNew )
{
    DB_InitCPTimes();
}

public void Influx_OnRecordRemoved( int issuer, int uid, int mapid, int runid, int mode, int style )
{
    DB_DeleteCPRecords( issuer, mapid, uid, runid, _, mode, style );
}

public void Influx_OnPrintRecordInfo( int client, Handle dbres, ArrayList itemlist, Menu menu, int uid, int mapid, int runid, int mode, int style )
{
    decl String:szInfo[64];
    
    FormatEx( szInfo, sizeof( szInfo ), "cp%i_%i_%i_%i_%i", uid, mapid, runid, mode, style );
    
    menu.AddItem( szInfo, "Checkpoint Records" );
}

public Action Influx_OnRecordInfoButtonPressed( int client, const char[] szInfo )
{
    if (szInfo[0] == 'c'
    &&  szInfo[1] == 'p')
    {
        decl String:buffer[5][12];
        if ( ExplodeString( szInfo[2], "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
        {
            return Plugin_Stop;
        }
        
        
        int uid = StringToInt( buffer[0] );
        int mapid = StringToInt( buffer[1] );
        int runid = StringToInt( buffer[2] );
        int mode = StringToInt( buffer[3] );
        int style = StringToInt( buffer[4] );
        
        
        DB_PrintCPTimes( client, uid, mapid, runid, mode, style );
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    if ( g_hClientCP[client] != null )
    {
        g_hClientCP[client].Clear();
    }
    
    g_iClientLatestCP[client] = 0;
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    // We don't get saved to db.
    if ( flags & RES_TIME_DONTSAVE ) return;
    
    
    if ( flags & (RES_TIME_PB | RES_TIME_FIRSTOWNREC) )
    {
        DB_InsertClientTimes( client, runid, mode, style, flags );
    }
}

public Action Influx_OnZoneLoad( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_CP ) return Plugin_Continue;
    
    
    int runid = kv.GetNum( "run_id", -1 );
    if ( runid < 1 )
    {
        LogError( INF_CON_PRE..."Checkpoint zone (id: %i) has invalid run id %i, loading anyway...",
            zoneid,
            runid );
    }
    
    int cpnum = kv.GetNum( "cp_num", -1 );
    if ( cpnum < 1 )
    {
        LogError( INF_CON_PRE..."Checkpoint zone (id: %i) has invalid cp num %i, loading anyway...",
            zoneid,
            cpnum );
    }
    
    //char szName[MAX_CP_NAME];
    //kv.GetString( "cp_name", szName, sizeof( szName ), "" );
    
    
    decl data[CPZONE_SIZE];
    
    data[CPZONE_ID] = zoneid;
    
    data[CPZONE_RUN_ID] = runid;
    
    data[CPZONE_NUM] = cpnum;
    
    data[CPZONE_ENTREF] = INVALID_ENT_REFERENCE;
    
    g_hCPZones.PushArray( data );
    
    
    AddCP( runid, cpnum );
    
    
    return Plugin_Handled;
}

public Action Influx_OnZoneSave( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_CP ) return Plugin_Continue;
    
    
    int index = FindCPZoneById( zoneid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Checkpoint zone (id: %i) is not registered with the plugin! Cannot save!",
            zoneid );
        return Plugin_Stop;
    }
    
    kv.SetNum( "run_id", g_hCPZones.Get( index, CPZONE_RUN_ID ) );
    
    kv.SetNum( "cp_num", g_hCPZones.Get( index, CPZONE_NUM ) );
    
    return Plugin_Handled;
}

public void Influx_OnZoneCreated( int client, int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_CP ) return;
    
    
    int runid = Influx_GetClientRunId( client );
    
    
    int cpnum = g_iBuildingNum[client];
    if ( cpnum < 1 )
    {
        LogError( INF_CON_PRE..."Checkpoint zone (id: %i) cannot be initialized because it has invalid cp num %i!",
            zoneid,
            cpnum );
        return;
    }
    
    
    decl data[CPZONE_SIZE];
    
    data[CPZONE_ID] = zoneid;
    
    data[CPZONE_RUN_ID] = runid;
    
    data[CPZONE_NUM] = cpnum;
    
    data[CPZONE_ENTREF] = INVALID_ENT_REFERENCE;
    
    g_hCPZones.PushArray( data );
    
    
    AddCP( runid, cpnum );
}

public void Influx_OnZoneDeleted( int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_CP ) return;
    
    
    int index = FindCPZoneById( zoneid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Couldn't find checkpoint zone with id %i to delete!", zoneid );
        return;
    }
    
    
    int runid = g_hCPZones.Get( index, CPZONE_RUN_ID );
    int cpnum = g_hCPZones.Get( index, CPZONE_NUM );
    
    
    g_hCPZones.Erase( index );
    
    
    // Check if any other cp zones exist with this run and num.
    // If not, delete our cp.
    if ( FindCPZoneByNum( runid, cpnum ) == -1 )
    {
        index = FindCPByNum( runid, cpnum );
        
        if ( index != -1 )
        {
            g_hCPs.Erase( index );
        }
    }
}

public void Influx_OnZoneSpawned( int zoneid, ZoneType_t zonetype, int ent )
{
    if ( zonetype != ZONETYPE_CP ) return;
    
    
    int index = FindCPZoneById( zoneid );
    if ( index == -1 ) return;
    
    
    // Update ent reference.
    g_hCPZones.Set( index, EntIndexToEntRef( ent ), CPZONE_ENTREF );
    
    
    SDKHook( ent, SDKHook_StartTouchPost, E_StartTouchPost_CP );
    
    
    Inf_SetZoneProp( ent, g_hCPZones.Get( index, CPZONE_ID ) );
}

public Action Influx_OnZoneBuildAsk( int client, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_CP ) return Plugin_Continue;
    
    
    
    int runid = Influx_GetClientRunId( client );
    
    
    char szDisplay[32];
    char szInfo[32];
    char szRun[MAX_RUN_NAME];
    
    
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    
    
    Menu menu = new Menu( Hndlr_CreateZone_SelectCPNum );
    menu.SetTitle( "Which checkpoint do you want to create?\nRun: %s\nCheckpoints: %i\n ",
        szRun,
        GetRunCPCount( runid ) );
    
    
    
    
    int highest = 0;
    
    int cpnum;
    
    
    int len = g_hCPs.Length;
    for( int i = 0; i < len; i++ )
    {
        if ( g_hCPs.Get( i, CP_RUN_ID ) != runid ) continue;
        
        
        cpnum = g_hCPs.Get( i, CP_NUM );
        
        if ( cpnum > highest )
        {
            highest = cpnum;
        }
    }
    
    ++highest;
    
    
    // Add highest to the top.
    FormatEx( szInfo, sizeof( szInfo ), "%i", highest );
    FormatEx( szDisplay, sizeof( szDisplay ), "New CP %i\n ", highest );
    
    menu.AddItem( szInfo, szDisplay );
    
    
    
    // Display them in a sorted order.
    
    
    for ( int i = 1; i < highest; i++ )
    {
        FormatEx( szInfo, sizeof( szInfo ), "%i", i );
        FormatEx( szDisplay, sizeof( szDisplay ), "CP %i", i );
        
        menu.AddItem( szInfo, szDisplay );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Stop;
}

public int Hndlr_CreateZone_SelectCPNum( Menu oldmenu, MenuAction action, int client, int index )
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
    
    
    int cpnum = StringToInt( szInfo );
    if ( cpnum < 1 ) return 0;
    
    
    int runid = Influx_GetClientRunId( client );
    
    
    if ( FindCPZoneByNum( runid, cpnum ) != -1 )
    {
        Menu menu = new Menu( Hndlr_CreateZone_SelectMethod );
        
        menu.SetTitle( "That CP already exists!\n " );
        
        menu.AddItem( szInfo, "Create a new instance (keep both)" );
        menu.AddItem( szInfo, "Replace existing one(s)\n " );
        menu.AddItem( "", "Cancel" );
        
        menu.ExitButton = false;
        
        menu.Display( client, MENU_TIME_FOREVER );
    }
    else
    {
        StartToBuild( client, cpnum );
    }
    
    return 0;
}

public int Hndlr_CreateZone_SelectMethod( Menu oldmenu, MenuAction action, int client, int index )
{
    MENU_HANDLE( oldmenu, action )
    
    
    char szInfo[16];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int cpnum = StringToInt( szInfo );
    if ( cpnum < 1 ) return 0;
    
    
    int runid = Influx_GetClientRunId( client );
    
    
    switch ( index )
    {
        case 0 : // Keep both
        {
            StartToBuild( client, cpnum );
        }
        case 1 : // Replace existing ones
        {
            int len = g_hCPZones.Length;
            for ( int i = 0; i < len; i++ )
            {
                if ( g_hCPZones.Get( i, CPZONE_RUN_ID ) != runid ) continue;
                
                if ( g_hCPZones.Get( i, CPZONE_NUM ) != cpnum ) continue;
                
                
                int zoneid = g_hCPZones.Get( i, CPZONE_ID );
                
                
                Influx_DeleteZone( zoneid );
                
                --i;
                len = g_hCPZones.Length;
            }
            
            StartToBuild( client, cpnum );
        }
    }
    
    return 0;
}

public void E_StartTouchPost_CP( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
    int zoneid = Inf_GetZoneProp( ent );
    
#if defined DEBUG_ZONE
    PrintToServer( INF_DEBUG_PRE..."Player %i hit cp with zone id %i (ent: %i)!", activator, zoneid, ent );
#endif
    
    int zindex = FindCPZoneById( zoneid );
    if ( zindex == -1 ) return;
    
    
    
    int runid = g_hCPZones.Get( zindex, CPZONE_RUN_ID );
    
    if ( Influx_GetClientRunId( activator ) != runid ) return;
    
    
    
    if ( ent != EntRefToEntIndex( g_hCPZones.Get( zindex, CPZONE_ENTREF ) ) )
    {
        return;
    }
    
    
    int cpnum = g_hCPZones.Get( zindex, CPZONE_NUM );
    
    SaveClientCP( activator, cpnum );
}

stock void SaveClientCP( int client, int cpnum )
{
#if defined DEBUG_INSERTCP
    PrintToServer( INF_DEBUG_PRE..."Attempting to save client cp %i!", cpnum );
#endif

    if ( Influx_GetClientState( client ) != STATE_RUNNING ) return;
    
    
    int runid = Influx_GetClientRunId( client );
    if ( Influx_FindRunById( runid ) == -1 ) return;
    
    
    int index = FindCPByNum( runid, cpnum );
    if ( index == -1 ) return;
    
    
    
#if defined DEBUG_INSERTCP
    PrintToServer( INF_DEBUG_PRE..."CP num is %i!", cpnum );
#endif
    
    
    // Update our cp times if we haven't gone in here yet.
    if ( !ShouldSaveCP( client, cpnum ) ) return;
    
    
    float time = Influx_GetClientTime( client );
    
#if defined DEBUG_INSERTCP
    PrintToServer( INF_DEBUG_PRE..."Inserting new client time %.3f", time );
#endif
    
    decl data[CCP_SIZE];
    data[CCP_NUM] = cpnum;
    data[CCP_TIME] = view_as<int>( time );
    
    g_hClientCP[client].PushArray( data );
    
    
    
    int mode = Influx_GetClientMode( client );
    int style = Influx_GetClientStyle( client );
    
    
    g_iClientLatestCP[client] = cpnum;
    
    g_flLastCPTime[client] = time;
    g_flLastCPPBTime[client] = GetClientCPTime( index, client, mode, style );
    g_flLastCPBestTime[client] = GetBestTime( index, mode, style );
    g_flLastCPSRTime[client] = GetRecordTime( index, mode, style );
    
    g_flLastTouch[client] = GetEngineTime();
    
    
    Call_StartForward( g_hForward_OnClientCPSavePost );
    Call_PushCell( client );
    Call_PushCell( cpnum );
    Call_Finish();
}

stock void StartToBuild( int client, int cpnum )
{
    int runid = Influx_GetClientRunId( client );
    
    g_iBuildingNum[client] = cpnum;
    g_iBuildingRunId[client] = runid;
    
    
    char szName[MAX_ZONE_NAME];
    char szRun[MAX_RUN_NAME];
    
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    
    FormatEx( szName, sizeof( szName ), "%s CP %i", szRun, cpnum );
    
    
    Influx_BuildZone( client, ZONETYPE_CP, szName );
    
    
    Inf_OpenZoneMenu( client );
}

stock int GetRunCPCount( int runid )
{
    int num = 0;
    
    int len = g_hCPs.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hCPs.Get( i, CP_RUN_ID ) == runid )
        {
            ++num;
        }
    }

    return num;
}

stock int FindCPZoneById( int id )
{
    int len = g_hCPZones.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hCPZones.Get( i, CPZONE_ID ) == id )
        {
            return i;
        }
    }
    
    return -1;
}

stock int FindCPByNum( int runid, int num )
{
    int len = g_hCPs.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hCPs.Get( i, CP_RUN_ID ) != runid ) continue;
        
        if ( g_hCPs.Get( i, CP_NUM ) == num )
        {
            return i;
        }
    }
    
    return -1;
}

stock int FindCPByRunId( int runid, int startindex = -1 )
{
    ++startindex;
    
    if ( startindex < 0 ) startindex = 0;
    
    
    int len = g_hCPs.Length;
    for ( int i = startindex; i < len; i++ )
    {
        if ( g_hCPs.Get( i, CP_RUN_ID ) == runid )
        {
            return i;
        }
    }
    
    return -1;
}

stock int FindCPZoneByNum( int runid, int num )
{
    int len = g_hCPZones.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hCPZones.Get( i, CPZONE_RUN_ID ) != runid ) continue;
        
        if ( g_hCPZones.Get( i, CPZONE_NUM ) == num )
        {
            return i;
        }
    }
    
    return -1;
}

stock bool ShouldSaveCP( int client, int cpnum )
{
    if ( g_hClientCP[client] == null ) return false;
    
    if ( cpnum <= g_iClientLatestCP[client] ) return false;
    
    
    // Start from the end.
    /*for ( int i = g_hClientCP[client].Length - 1; i >= 0; i-- )
    {
        if ( g_hClientCP[client].Get( i, CCP_NUM ) >= cpnum )
        {
            return false;
        }
    }*/
    
    return true;
}

stock int AddCP( int runid, int cpnum, const char[] szName = "", bool bUpdateName = false )
{
    int index;
    
    index = FindCPByNum( runid, cpnum );
    if ( index != -1 )
    {
        // Update our name.
        if ( bUpdateName && szName[0] != '\0' )
        {
            decl name[MAX_CP_NAME_CELL];
            
            strcopy( view_as<char>( name ), MAX_CP_NAME, szName );
            
            for ( int i = 0; i < MAX_CP_NAME_CELL; i++ )
            {
                g_hCPs.Set( index, name[i], CP_NAME + i );
            }
        }
        
        return index;
    }
    
    
    int data[CP_SIZE];
    
    if ( szName[0] != '\0' )
    {
        strcopy( view_as<char>( data[CP_NAME] ), MAX_CP_NAME, szName );
    }
    else
    {
        FormatEx( view_as<char>( data[CP_NAME] ), MAX_CP_NAME, "CP #%i", cpnum );
    }
    
    data[CP_NUM] = cpnum;
    data[CP_RUN_ID] = runid;
    
    index = g_hCPs.PushArray( data );
    
    
    // If we already have a map id, get times for this new cp.
    //if ( Influx_GetCurrentMapId() > 1 )
    //{
    //    DB_GetCPTimes( runid, _, _, cpnum );
    //}
    
    
    return index;
}

stock void GetCPName( int index, char[] sz, int len )
{
    decl data[MAX_CP_NAME_CELL];
    
    for ( int i = 0; i < MAX_CP_NAME_CELL; i++ )
    {
        data[i] = g_hCPs.Get( index, CP_NAME + i );
    }
    
    strcopy( sz, len, view_as<char>( data ) );
}

stock float GetBestTime( int index, int mode, int style )
{
    return view_as<float>( g_hCPs.Get( index, CP_BESTTIMES + OFFSET_MODESTYLE( mode, style ) ) );
}

stock int GetBestTimeId( int index, int mode, int style )
{
    return g_hCPs.Get( index, CP_BESTTIMES_UID + OFFSET_MODESTYLE( mode, style ) );
}

stock void SetBestTime( int index, int mode, int style, float time, int uid = 0 )
{
#if defined DEBUG_SETS
    PrintToServer( INF_DEBUG_PRE..."Setting best time (%i, %i, %.3f, %i)", mode, style, time, uid );
#endif
    
    int offset = OFFSET_MODESTYLE( mode, style );
    
    g_hCPs.Set( index, time, CP_BESTTIMES + offset );
    g_hCPs.Set( index, uid, CP_BESTTIMES_UID + offset );
}

stock float GetRecordTime( int index, int mode, int style )
{
    return view_as<float>( g_hCPs.Get( index, CP_RECTIMES + OFFSET_MODESTYLE( mode, style ) ) );
}

stock int GetRecordTimeId( int index, int mode, int style )
{
    return g_hCPs.Get( index, CP_RECTIMES_UID + OFFSET_MODESTYLE( mode, style ) );
}

stock void SetRecordTime( int index, int mode, int style, float time, int uid = 0 )
{
#if defined DEBUG_SETS
    PrintToServer( INF_DEBUG_PRE..."Setting record time (%i, %i, %.3f, %i)", mode, style, time, uid );
#endif
    
    int offset = OFFSET_MODESTYLE( mode, style );
    
    g_hCPs.Set( index, time, CP_RECTIMES + offset );
    g_hCPs.Set( index, uid, CP_RECTIMES_UID + offset );
}

stock float GetClientCPTime( int index, int client, int mode, int style )
{
    return g_hCPs.Get( index, CP_CLIENTTIMES + OFFSET_MODESTYLECLIENT( mode, style, client ) );
}

stock void SetClientCPTime( int index, int client, int mode, int style, float time )
{
#if defined DEBUG_SETS
    PrintToServer( INF_DEBUG_PRE..."Setting client %i cp time (%i, %i, %.3f)", client, mode, style, time );
#endif
    
    g_hCPs.Set( index, time, CP_CLIENTTIMES + OFFSET_MODESTYLECLIENT( mode, style, client ) );
}

/*stock void GetRunRecordName( ArrayList stages, int index, int mode, int style, char[] out, int len )
{
    decl name[MAX_BEST_NAME_CELL];
    
    GetName( stages, index, STAGE_RECTIMES_NAME, mode, style, name );
    
    strcopy( out, len, view_as<char>( name ) );
}*/

/*stock void GetRunBestName( ArrayList stages, int index, int mode, int style, char[] out, int len )
{
    decl name[MAX_BEST_NAME_CELL];
    
    GetName( stages, index, STAGE_BESTTIMES_NAME, mode, style, name );
    
    strcopy( out, len, view_as<char>( name ) );
}*/

/*stock void SetRecordName( ArrayList stages, int index, int mode, int style, const char[] szName )
{
    SetName( stages, index, STAGE_RECTIMES_NAME, mode, style, szName );
}*/

/*stock void SetBestName( ArrayList stages, int index, int mode, int style, const char[] szName )
{
    SetName( stages, index, STAGE_BESTTIMES_NAME, mode, style, szName );
}

stock void SetName( ArrayList stages, int index, int block, int mode, int style, const char[] szName )
{
    decl String:sz[MAX_BEST_NAME + 1];
    decl name[MAX_BEST_NAME_CELL];
    
    strcopy( sz, sizeof( sz ), szName );
    
    
    LimitString( sz, sizeof( sz ), MAX_BEST_NAME );
    
    
    strcopy( view_as<char>( name ), MAX_BEST_NAME, sz );
    
    
    int offset = block + OFFSET_MODESTYLESIZE( mode, style, MAX_BEST_NAME_CELL );
    
    for ( int i = 0; i < sizeof( name ); i++ )
    {
        stages.Set( index, name[i], offset + i );
    }
}

stock void GetName( ArrayList stages, int index, int block, int mode, int style, int name[MAX_BEST_NAME_CELL] )
{
    int offset = block + OFFSET_MODESTYLESIZE( mode, style, MAX_BEST_NAME_CELL );
    
    for ( int i = 0; i < sizeof( name ); i++ )
    {
        name[i] = stages.Get( index, offset + i );
    }
}*/

stock void ResetCPTimes( int runid, int cpnum )
{
    int index = FindCPByNum( runid, cpnum );
    if ( index == -1 ) return;
    
    
    decl m, s;
    
    for ( m = 0; m < MAX_MODES; m++ )
        for ( s = 0; s < MAX_STYLES; s++ )
        {
            SetRecordTime( index, m, s, INVALID_RUN_TIME );
            SetBestTime( index, m, s, INVALID_RUN_TIME );
            //SetBestName( index, m, s, "" );
        }
}

stock int FindClientCPByNum( int client, int num )
{
    int len = GetArrayLength_Safe( g_hClientCP[client] );
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hClientCP[client].Get( i, CCP_NUM ) == num )
        {
            return i;
        }
    }

    return -1;
}

stock bool CanUserModifyCPTimes( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_REMOVECPRECORDS, ADMFLAG_ROOT );
}

stock void ResetClientCPTimes( int client )
{
    decl i, j, k;
    
    int len = g_hCPs.Length;
    for ( i = 0; i < len; i++ )
        for ( j = 0; j < MAX_MODES; j++ )
            for ( k = 0; k < MAX_STYLES; k++ )
            {
                SetClientCPTime( i, client, j, k, INVALID_RUN_TIME );
            }
}

stock void ResetClientRunCPTimes( int client, int runid, int mode, int style )
{
    int index = -1;
    
    while ( (index = FindCPByRunId( runid, index )) != -1 )
    {
        SetClientCPTime( index, client, mode, style, INVALID_RUN_TIME );
    }
}

stock bool ResetCPTimesByUId( int uid, int runid, int mode, int style )
{
    bool deleted = false;
    
    
    int index = -1;
    
    while ( (index = FindCPByRunId( runid, index )) != -1 )
    {
        if ( GetBestTimeId( index, mode, style ) == uid )
        {
            SetBestTime( index, mode, style, INVALID_RUN_TIME, 0 );
            
            deleted = true;
        }
        
        if ( GetRecordTimeId( index, mode, style ) == uid )
        {
            SetRecordTime( index, mode, style, INVALID_RUN_TIME, 0 );
            
            deleted = true;
        }
    }
    
    return deleted;
}

// CMDS
public Action Cmd_PrintCps( int client, int args )
{
    int len = g_hCPs.Length;
    for ( int i = 0; i < len; i++ )
    {
        PrintToServer( INF_DEBUG_PRE..."CP #%i | Run Id: %i",
            g_hCPs.Get( i, CP_NUM ),
            g_hCPs.Get( i, CP_RUN_ID ) );
    }
    
    return Plugin_Handled;
}

// NATIVES
public int Native_SaveClientCP( Handle hPlugin, int nParms )
{
    SaveClientCP( GetNativeCell( 1 ), GetNativeCell( 2 ) );
    
    return 1;
}

public int Native_AddCP( Handle hPlugin, int nParms )
{
    decl String:szName[MAX_CP_NAME];
    
    int runid = GetNativeCell( 1 );
    int cpnum = GetNativeCell( 2 );
    
    GetNativeString( 3, szName, sizeof( szName ) );
    
    
    AddCP( runid, cpnum, szName );
    
    return 1;
}

/*public int Native_PrintCPTimes( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    int uid = GetNativeCell( 2 );
    int mapid = GetNativeCell( 3 );
    int runid = GetNativeCell( 4 );
    int mode = GetNativeCell( 5 );
    int style = GetNativeCell( 6 );
    
    
    DB_PrintCPTimes( client, uid, mapid, runid, mode, style );
    
    return 1;
}*/

public int Native_GetClientLastCP( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return g_iClientLatestCP[client];
}

public int Native_GetClientLastCPTouch( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_flLastTouch[client] );
}

public int Native_GetClientLastCPTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_flLastCPTime[client] );
}

public int Native_GetClientLastCPPBTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_flLastCPPBTime[client] );
}

public int Native_GetClientLastCPBestTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_flLastCPBestTime[client] );
}

public int Native_GetClientLastCPSRTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_flLastCPSRTime[client] );
}
