#include <sourcemod>
#include <clientprefs>

#include <influx/core>
#include <influx/hud>


#undef REQUIRE_PLUGIN
#include <influx/help>



#define MAX_MENUCMD_NAME        24

#define MAX_MENUCMD_CMD         24

enum struct MenuCmd_t
{
    char szName[MAX_MENUCMD_NAME];
    char szCmd[MAX_MENUCMD_NAME];
}

ArrayList g_hMenuCmds;


Handle g_hCookie_HideFlags;

int g_fHideFlags[INF_MAXPLAYERS];


// FORWARDS
Handle g_hForward_OnRequestHUDMenuCmds;


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
}

public void OnPluginStart()
{
    if ( (g_hCookie_HideFlags = RegClientCookie( "influx_hideflags", INF_NAME..." HUD Flags", CookieAccess_Protected )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't register hideflags cookie!" );
    }
    
    
    // FORWARDS
    g_hForward_OnRequestHUDMenuCmds = CreateGlobalForward( "Influx_OnRequestHUDMenuCmds", ET_Ignore );
    
    
    // CMDS
    RegConsoleCmd( "sm_hud", Cmd_Hud );
}

public void OnAllPluginsLoaded()
{
    delete g_hMenuCmds;
    g_hMenuCmds = new ArrayList( sizeof( MenuCmd_t ) );
    
    
    Call_StartForward( g_hForward_OnRequestHUDMenuCmds );
    Call_Finish();
}

public void OnClientDisconnect( int client )
{
    if ( !IsFakeClient( client ) )
    {
        char szCookie[12];
        IntToString( g_fHideFlags[client], szCookie, sizeof( szCookie ) );
        
        SetClientCookie( client, g_hCookie_HideFlags, szCookie );
    }
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

public Action Cmd_Hud( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    int len = GetArrayLength_Safe( g_hMenuCmds );
    if ( len < 1 ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "Settings:\n " );
    
    MenuCmd_t cmd;
    
    for ( int i = 0; i < len; i++ )
    {
        g_hMenuCmds.GetArray( i, cmd );
        
        menu.AddItem( cmd.szCmd, menu.szName );
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
    
    
    MenuCmd_t cmd;
    
    GetNativeString( 1, cmd.szCmd, sizeof( MenuCmd_t::szCmd ) );
    GetNativeString( 2, cmd.szName, sizeof( MenuCmd_t::szName ) );
    
    g_hMenuCmds.PushArray( data );
    
    return 1;
}