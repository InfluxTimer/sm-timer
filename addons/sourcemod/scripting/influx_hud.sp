#include <sourcemod>
#include <clientprefs>

#include <influx/core>
#include <influx/hud>


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
    g_hMenuCmds = new ArrayList( MENUCMD_SIZE );
    
    
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