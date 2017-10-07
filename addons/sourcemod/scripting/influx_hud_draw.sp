#include <sourcemod>

#include <influx/core>
#include <influx/hud_draw>


#undef REQUIRE_PLUGIN
#include <influx/hud>

#include <msharedutil/ents>


float g_flNextDraw_Timer[INF_MAXPLAYERS];
float g_flNextDraw_Sidebar[INF_MAXPLAYERS];
float g_flNextDraw_Menu[INF_MAXPLAYERS];


int g_nNextTimer;
int g_nNextSidebar;
int g_nNextHudMsg;
int g_nNextMenu;


// CONVARS
ConVar g_ConVar_Timer;
ConVar g_ConVar_HudMsg;
ConVar g_ConVar_Sidebar;
ConVar g_ConVar_Menu;

ConVar g_ConVar_NumDecimals_Timer;
ConVar g_ConVar_NumDecimals_Sidebar;


char g_szFormat_Timer[12] = "%04.1f";
char g_szFormat_Sidebar[12] = "%05.2f";


// FORWARDS
Handle g_hForward_ShouldDrawHUD;
Handle g_hForward_OnDrawHUD;


// LIBRARIES
bool g_bLib_Hud;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - HUD Draw",
    description = "Handles drawing.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_HUD_DRAW );
    
    
    // NATIVES
    CreateNative( "Influx_GetSecondsFormat_Timer", Native_GetSecondsFormat_Timer );
    CreateNative( "Influx_GetSecondsFormat_Sidebar", Native_GetSecondsFormat_Sidebar );
    
    CreateNative( "Influx_GetNextMenuTime", Native_GetNextMenuTime );
    CreateNative( "Influx_SetNextMenuTime", Native_SetNextMenuTime );
}

public void OnPluginStart()
{
    // FORWARDS
    g_hForward_ShouldDrawHUD = CreateGlobalForward( "Influx_ShouldDrawHUD", ET_Hook, Param_Cell, Param_Cell, Param_Cell );
    g_hForward_OnDrawHUD = CreateGlobalForward( "Influx_OnDrawHUD", ET_Hook, Param_Cell, Param_Cell, Param_Cell );
    
    
    // CONVARS
    g_ConVar_Timer = CreateConVar( "influx_hud_draw_timerinterval", "0.1", "Draw interval for timer. < 0 = disable", FCVAR_NOTIFY, true, -1.0, true, 1.0 );
    
    g_ConVar_Sidebar = CreateConVar( "influx_hud_draw_sidebarinterval", "0.75", "Draw interval for sidebar. < 0 = disable", FCVAR_NOTIFY, true, -1.0, true, 5.0 );
    
    g_ConVar_HudMsg = CreateConVar( "influx_hud_draw_hudmsginterval", "0.75", "Draw interval for HudMsg. < 0 = disable", FCVAR_NOTIFY, true, -1.0, true, 5.0 );
    
    g_ConVar_Menu = CreateConVar( "influx_hud_draw_menuinterval", "0.75", "Draw interval for sidebar menu. < 0 = disable", FCVAR_NOTIFY, true, -1.0, true, 5.0 );
    
    
    g_ConVar_NumDecimals_Timer = CreateConVar( "influx_hud_draw_numdecimals_timer", "1", "Number of decimals to show on the timer.", FCVAR_NOTIFY, true, 0.0, true, 3.0 );
    HookConVarChange( g_ConVar_NumDecimals_Timer, E_ConVarChanged_NumDecimals_Timer );
    
    g_ConVar_NumDecimals_Sidebar = CreateConVar( "influx_hud_draw_numdecimals_sidebar", "2", "Number of decimals to show on the sidebar.", FCVAR_NOTIFY, true, 0.0, true, 3.0 );
    HookConVarChange( g_ConVar_NumDecimals_Sidebar, E_ConVarChanged_NumDecimals_Sidebar );
    
    AutoExecConfig( true, "hud_draw", "influx" );
    
    
    // LIBRARIES
    g_bLib_Hud = LibraryExists( INFLUX_LIB_HUD );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_HUD ) ) g_bLib_Hud = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_HUD ) ) g_bLib_Hud = false;
}

public void OnMapStart()
{
    g_nNextTimer = 0;
    g_nNextHudMsg = 0;
    g_nNextSidebar = 0;
    g_nNextMenu = 0;
}

public void OnClientPutInServer( int client )
{
    float next = GetEngineTime() + 2.0;
    
    g_flNextDraw_Timer[client] = next;
    g_flNextDraw_Sidebar[client] = next;
    g_flNextDraw_Menu[client] = next;
}

stock int GetClientTarget( int client )
{
    if ( !IsPlayerAlive( client ) )
    {
        int target = GetClientObserverTarget( client );
        
        return (
            IS_ENT_PLAYER( target )
        &&  IsClientInGame( target )
        &&  IsPlayerAlive( target )
        &&  GetClientObserverMode( client ) != OBS_MODE_ROAMING ) ? target : 0;
    }
    else
    {
        return client;
    }
}

public void OnGameFrame()
{
    // Use OnGameFrame instead of timers since they cannot refire in less than 0.1 seconds.
    int tick = GetGameTickCount();
    
    if ( tick >= g_nNextTimer && g_ConVar_Timer.FloatValue >= 0.0 )
    {
        DrawTimer();
        
        g_nNextTimer = tick + RoundFloat( g_ConVar_Timer.FloatValue / GetTickInterval() );
    }
    
    if ( tick >= g_nNextSidebar && g_ConVar_Sidebar.FloatValue >= 0.0 )
    {
        DrawSidebar();
        
        g_nNextSidebar = tick + RoundFloat( g_ConVar_Sidebar.FloatValue / GetTickInterval() );
    }
    
    if ( tick >= g_nNextHudMsg && g_ConVar_HudMsg.FloatValue >= 0.0 )
    {
        DrawHudMsg();
        
        g_nNextHudMsg = tick + RoundFloat( g_ConVar_HudMsg.FloatValue / GetTickInterval() );
    }
    
    if ( tick >= g_nNextMenu && g_ConVar_Menu.FloatValue >= 0.0 )
    {
        DrawMenu();
        
        g_nNextMenu = tick + RoundFloat( g_ConVar_Menu.FloatValue / GetTickInterval() );
    }
}

stock bool ShouldDraw( int client, int target, HudType_t hudtype )
{
    Action res;
    
    Call_StartForward( g_hForward_ShouldDrawHUD );
    Call_PushCell( client );
    Call_PushCell( target );
    Call_PushCell( hudtype );
    Call_Finish( res );
    
    return ( res == Plugin_Continue );
}

stock bool OnDrawHUD( int client, int target, HudType_t hudtype )
{
    Call_StartForward( g_hForward_OnDrawHUD );
    Call_PushCell( client );
    Call_PushCell( target );
    Call_PushCell( hudtype );
    Call_Finish();
}

stock void DrawTimer()
{
    float engtime = GetEngineTime();
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) || IsFakeClient( i ) ) continue;
        
        if ( g_flNextDraw_Timer[i] > engtime ) continue;
        
        if ( g_bLib_Hud && Influx_GetClientHideFlags( i ) & HIDEFLAG_TIMER ) continue;
        
        int target = GetClientTarget( i );
        if ( !target ) continue;
        
        if ( !ShouldDraw( i, target, HUDTYPE_TIMER ) ) continue;
        
        
        OnDrawHUD( i, target, HUDTYPE_TIMER );
    }
}

stock void DrawSidebar()
{
    float engtime = GetEngineTime();
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) || IsFakeClient( i ) ) continue;
        
        if ( g_flNextDraw_Sidebar[i] > engtime ) continue;
        
        if ( g_bLib_Hud && Influx_GetClientHideFlags( i ) & HIDEFLAG_SIDEBAR ) continue;
        
        int target = GetClientTarget( i );
        if ( !target ) continue;
        
        if ( !ShouldDraw( i, target, HUDTYPE_SIDEBAR ) ) continue;
        
        
        OnDrawHUD( i, target, HUDTYPE_SIDEBAR );
    }
}

stock void DrawHudMsg()
{
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) || IsFakeClient( i ) ) continue;
        
        if ( g_bLib_Hud && Influx_GetClientHideFlags( i ) & HIDEFLAG_SIDEBAR ) continue;
        
        
        int target = GetClientTarget( i );
        if ( !target ) continue;
        
        if ( !ShouldDraw( i, target, HUDTYPE_HUDMSG ) ) continue;
        
        
        OnDrawHUD( i, target, HUDTYPE_HUDMSG );
    }
}

stock void DrawMenu()
{
    float engtime = GetEngineTime();
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) || IsFakeClient( i ) ) continue;
        
        if ( g_flNextDraw_Menu[i] > engtime ) continue;
        
        if ( g_bLib_Hud && Influx_GetClientHideFlags( i ) & HIDEFLAG_SIDEBAR ) continue;
        
        // Only display if no other menu is being displayed.
        MenuSource menusrc = GetClientMenu( i, null );
        if ( menusrc != MenuSource_None && menusrc != MenuSource_RawPanel ) continue;
        
        
        int target = GetClientTarget( i );
        if ( !target ) continue;
        
        if ( !ShouldDraw( i, target, HUDTYPE_MENU ) ) continue;
        
        
        OnDrawHUD( i, target, HUDTYPE_MENU );
    }
}

public void E_ConVarChanged_NumDecimals_Timer( ConVar convar, const char[] oldValue, const char[] newValue )
{
    Inf_DecimalFormat( convar.IntValue, g_szFormat_Timer, sizeof( g_szFormat_Timer ) );
}

public void E_ConVarChanged_NumDecimals_Sidebar( ConVar convar, const char[] oldValue, const char[] newValue )
{
    Inf_DecimalFormat( convar.IntValue, g_szFormat_Sidebar, sizeof( g_szFormat_Sidebar ) );
}

public int Native_GetNextMenuTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_flNextDraw_Menu[client] );
}

public int Native_SetNextMenuTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    g_flNextDraw_Menu[client] = GetNativeCell( 2 );
    
#if defined DEBUG_MENUTIME
    PrintToServer( INF_DEBUG_PRE..."Set client %i menu time to %.1f", client, g_flNextDraw_Menu[client] );
#endif
    
    return 1;
}

public int Native_GetSecondsFormat_Timer( Handle hPlugin, int numParams )
{
    SetNativeString( 1, g_szFormat_Timer, GetNativeCell( 2 ) );
    return 1;
}

public int Native_GetSecondsFormat_Sidebar( Handle hPlugin, int numParams )
{
    SetNativeString( 1, g_szFormat_Sidebar, GetNativeCell( 2 ) );
    return 1;
}