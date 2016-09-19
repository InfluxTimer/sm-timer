#include <sourcemod>
#include <clientprefs>

#include <influx/core>
#include <influx/hud>

#include <msharedutil/ents>


#undef REQUIRE_PLUGIN
#include <influx/help>



#define MAX_MENUCMD_NAME        24
#define MAX_MENUCMD_NAME_CELL   MAX_MENUCMD_NAME / 4

#define MAX_MENUCMD_CMD         24
#define MAX_MENUCMD_CMD_CELL    MAX_MENUCMD_CMD / 4

enum
{
    MENUCMD_NAME[MAX_MENUCMD_NAME_CELL] = 0,
    MENUCMD_CMD[MAX_MENUCMD_CMD_CELL],
    
    MENUCMD_SIZE
};

ArrayList g_hMenuCmds;


Handle g_hCookie_HideFlags;

int g_fHideFlags[INF_MAXPLAYERS];


float g_flNextDraw_Timer[INF_MAXPLAYERS];
float g_flNextDraw_Sidebar[INF_MAXPLAYERS];

float g_flNextMenuTime[INF_MAXPLAYERS];


// TIMERS
Handle g_hTimer_Hint;
Handle g_hTimer_KeyHint;
Handle g_hTimer_Menu;


// CONVARS
ConVar g_ConVar_Hint;
ConVar g_ConVar_KeyHint;
ConVar g_ConVar_Menu;

ConVar g_ConVar_NumDecimals_Timer;
ConVar g_ConVar_NumDecimals_Sidebar;

char g_szFormat_Timer[12] = "%04.1f";
char g_szFormat_Sidebar[12] = "%05.2f";


// FORWARDS
Handle g_hForward_OnRequestHUDMenuCmds;
Handle g_hForward_ShouldDrawHUD;
Handle g_hForward_OnDrawHUD;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - HUD",
    description = "Manages settings.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_HUD );
    
    // NATIVES
    CreateNative( "Influx_GetClientHideFlags", Native_GetClientHideFlags );
    CreateNative( "Influx_SetClientHideFlags", Native_SetClientHideFlags );
    
    CreateNative( "Influx_AddHUDMenuCmd", Native_AddHUDMenuCmd );
    
    CreateNative( "Influx_GetSecondsFormat_Timer", Native_GetSecondsFormat_Timer );
    CreateNative( "Influx_GetSecondsFormat_Sidebar", Native_GetSecondsFormat_Sidebar );
    
    
    CreateNative( "Influx_GetNextMenuTime", Native_GetNextMenuTime );
    CreateNative( "Influx_SetNextMenuTime", Native_SetNextMenuTime );
}

public void OnPluginStart()
{
    if ( (g_hCookie_HideFlags = RegClientCookie( "influx_hideflags", INF_NAME..." HUD Flags", CookieAccess_Protected )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't register hideflags cookie!" );
    }
    
    
    // FORWARDS
    g_hForward_OnRequestHUDMenuCmds = CreateGlobalForward( "Influx_OnRequestHUDMenuCmds", ET_Ignore );
    
    g_hForward_ShouldDrawHUD = CreateGlobalForward( "Influx_ShouldDrawHUD", ET_Hook, Param_Cell, Param_Cell, Param_Cell );
    g_hForward_OnDrawHUD = CreateGlobalForward( "Influx_OnDrawHUD", ET_Hook, Param_Cell, Param_Cell, Param_Cell );
    
    
    // CONVARS
    g_ConVar_Hint = CreateConVar( "influx_hud_hintdrawinterval", "0.1", "Draw interval for timer. 0 = disable", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    HookConVarChange( g_ConVar_Hint, E_ConVarChanged_Hint );
    
    g_ConVar_KeyHint = CreateConVar( "influx_hud_keyhintdrawinterval", "0.75", "Draw interval for CSS sidebar. 0 = disable", FCVAR_NOTIFY, true, 0.0, true, 5.0 );
    HookConVarChange( g_ConVar_KeyHint, E_ConVarChanged_KeyHint );
    
    g_ConVar_Menu = CreateConVar( "influx_hud_menudrawinterval", "0.75", "Draw interval for CS:GO menu sidebar. 0 = disable", FCVAR_NOTIFY, true, 0.0, true, 5.0 );
    HookConVarChange( g_ConVar_Menu, E_ConVarChanged_Menu );
    
    
    g_ConVar_NumDecimals_Timer = CreateConVar( "influx_hud_numdecimals_timer", "1", "Number of decimals to show on the timer.", FCVAR_NOTIFY, true, 0.0, true, 3.0 );
    HookConVarChange( g_ConVar_NumDecimals_Timer, E_ConVarChanged_NumDecimals_Timer );
    
    g_ConVar_NumDecimals_Sidebar = CreateConVar( "influx_hud_numdecimals_sidebar", "2", "Number of decimals to show on the sidebar.", FCVAR_NOTIFY, true, 0.0, true, 3.0 );
    HookConVarChange( g_ConVar_NumDecimals_Sidebar, E_ConVarChanged_NumDecimals_Sidebar );
    
    AutoExecConfig( true, "hud", "influx" );
    
    
    // CMDS
    RegConsoleCmd( "sm_hud", Cmd_Hud );
}

public void OnAllPluginsLoaded()
{
    delete g_hMenuCmds;
    g_hMenuCmds = new ArrayList( MENUCMD_SIZE );
    
    
    Call_StartForward( g_hForward_OnRequestHUDMenuCmds );
    Call_Finish();
}

public void OnMapStart()
{
    StartHint();
    StartKeyHint();
    StartMenu();
}

public void OnMapEnd()
{
    g_hTimer_Hint = null;
    g_hTimer_KeyHint = null;
    g_hTimer_Menu = null;
}

public void OnClientPutInServer( int client )
{
    g_flNextMenuTime[client] = 0.0;
    
    
    float next = GetEngineTime() + 2.0;
    
    g_flNextDraw_Timer[client] = next;
    g_flNextDraw_Sidebar[client] = next;
}

public void OnClientDisconnect( int client )
{
    if ( !IsFakeClient( client ) )
    {
        char szCookie[12];
        IntToString( g_fHideFlags[client], szCookie, sizeof( szCookie ) );
        
        SetClientCookie( client, g_hCookie_HideFlags, szCookie );
    }
    
    g_flNextDraw_Timer[client] = 0.0;
    g_flNextDraw_Sidebar[client] = 0.0;
}

public void OnClientCookiesCached( int client )
{
    if ( AreClientCookiesCached( client ) )
    {
        char szCookie[12];
        GetClientCookie( client, g_hCookie_HideFlags, szCookie, sizeof( szCookie ) );
        
        if ( szCookie[0] != '\0' )
        {
            g_fHideFlags[client] = StringToInt( szCookie );
        }
        else
        {
            g_fHideFlags[client] = DEF_HIDEFLAGS;
        }
    }
    else
    {
        g_fHideFlags[client] = DEF_HIDEFLAGS;
    }
}

public void Influx_OnRequestHelpCmds()
{
    Influx_AddHelpCommand( "hud", "HUD option menu." );
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

stock void StartHint()
{
    if ( g_ConVar_Hint.FloatValue == 0.0 ) return;
    
    
    g_hTimer_Hint = CreateTimer( g_ConVar_Hint.FloatValue, T_DrawHint, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

stock void StartKeyHint()
{
    if ( GetEngineVersion() != Engine_CSS ) return;
    
    if ( g_ConVar_KeyHint.FloatValue == 0.0 ) return;
    
    
    g_hTimer_KeyHint = CreateTimer( g_ConVar_KeyHint.FloatValue, T_DrawKeyHint, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

stock void StartMenu()
{
    if ( GetEngineVersion() != Engine_CSGO ) return;
    
    if ( g_ConVar_Menu.FloatValue == 0.0 ) return;
    
    
    g_hTimer_Menu = CreateTimer( g_ConVar_Menu.FloatValue, T_DrawMenu, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
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

public Action T_DrawHint( Handle hTimer )
{
    float engtime = GetEngineTime();
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) || IsFakeClient( i ) ) continue;
        
        if ( g_flNextDraw_Timer[i] > engtime ) continue;
        
        if ( g_fHideFlags[i] & HIDEFLAG_TIMER ) continue;
        
        int target = GetClientTarget( i );
        if ( !target ) continue;
        
        if ( !ShouldDraw( i, target, HUDTYPE_HINT ) ) continue;
        
        
        OnDrawHUD( i, target, HUDTYPE_HINT );
    }
    
    return Plugin_Continue;
}

public Action T_DrawKeyHint( Handle hTimer )
{
    float engtime = GetEngineTime();
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) || IsFakeClient( i ) ) continue;
        
        if ( g_flNextDraw_Sidebar[i] > engtime ) continue;
        
        if ( g_fHideFlags[i] & HIDEFLAG_SIDEBAR ) continue;
        
        int target = GetClientTarget( i );
        if ( !target ) continue;
        
        if ( !ShouldDraw( i, target, HUDTYPE_KEYHINT ) ) continue;
        
        
        OnDrawHUD( i, target, HUDTYPE_KEYHINT );
    }
    
    return Plugin_Continue;
}

public Action T_DrawMenu( Handle hTimer )
{
    float engtime = GetEngineTime();
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) || IsFakeClient( i ) ) continue;
        
        if ( g_flNextDraw_Sidebar[i] > engtime ) continue;
        
        if ( g_fHideFlags[i] & HIDEFLAG_SIDEBAR ) continue;
        
        
        if ( g_flNextMenuTime[i] > engtime ) continue;
        
        // Only display if no other menu is being displayed.
        MenuSource menusrc = GetClientMenu( i, null );
        if ( menusrc != MenuSource_None && menusrc != MenuSource_RawPanel ) continue;
        
        
        int target = GetClientTarget( i );
        if ( !target ) continue;
        
        if ( !ShouldDraw( i, target, HUDTYPE_MENU_CSGO ) ) continue;
        
        
        OnDrawHUD( i, target, HUDTYPE_MENU_CSGO );
    }
    
    return Plugin_Continue;
}

public void E_ConVarChanged_Hint( ConVar convar, const char[] oldValue, const char[] newValue )
{
    KillTimer( g_hTimer_Hint );
    StartHint();
}

public void E_ConVarChanged_KeyHint( ConVar convar, const char[] oldValue, const char[] newValue )
{
    KillTimer( g_hTimer_KeyHint );
    StartKeyHint();
}

public void E_ConVarChanged_Menu( ConVar convar, const char[] oldValue, const char[] newValue )
{
    KillTimer( g_hTimer_Menu );
    StartMenu();
}

public void E_ConVarChanged_NumDecimals_Timer( ConVar convar, const char[] oldValue, const char[] newValue )
{
    Inf_DecimalFormat( convar.IntValue, g_szFormat_Timer, sizeof( g_szFormat_Timer ) );
}

public void E_ConVarChanged_NumDecimals_Sidebar( ConVar convar, const char[] oldValue, const char[] newValue )
{
    Inf_DecimalFormat( convar.IntValue, g_szFormat_Sidebar, sizeof( g_szFormat_Sidebar ) );
}

public Action Cmd_Hud( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    int len = GetArrayLength_Safe( g_hMenuCmds );
    if ( len < 1 ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "Settings:\n " );
    
    decl data[MENUCMD_SIZE];
    
    for ( int i = 0; i < len; i++ )
    {
        g_hMenuCmds.GetArray( i, data );
        
        menu.AddItem( view_as<char>( data[MENUCMD_CMD] ), view_as<char>( data[MENUCMD_NAME] ) );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Hndlr_Settings( Menu menu, MenuAction action, int client, int index )
{
    if ( action == MenuAction_End ) { delete menu; return 0; }
    if ( action != MenuAction_Select ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    FakeClientCommand( client, szInfo );
    
    
    return 0;
}

// NATIVES
public int Native_GetClientHideFlags( Handle hPlugin, int numParams )
{
    return g_fHideFlags[GetNativeCell( 1 )];
}

public int Native_SetClientHideFlags( Handle hPlugin, int numParams )
{
    g_fHideFlags[GetNativeCell( 1 )] = GetNativeCell( 2 );
    
    return 1;
}

public int Native_AddHUDMenuCmd( Handle hPlugin, int numParams )
{
    if ( g_hMenuCmds == null ) return 0;
    
    
    decl data[MENUCMD_SIZE];
    
    GetNativeString( 1, view_as<char>( data[MENUCMD_CMD] ), MAX_MENUCMD_CMD );
    GetNativeString( 2, view_as<char>( data[MENUCMD_NAME] ), MAX_MENUCMD_NAME );
    
    g_hMenuCmds.PushArray( data );
    
    return 1;
}

public int Native_GetNextMenuTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_flNextMenuTime[client] );
}

public int Native_SetNextMenuTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    g_flNextMenuTime[client] = GetNativeCell( 2 );
    
#if defined DEBUG_MENUTIME
    PrintToServer( INF_DEBUG_PRE..."Set client %i menu time to %.1f", client, g_flNextMenuTime[client] );
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