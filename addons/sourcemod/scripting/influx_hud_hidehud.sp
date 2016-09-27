#include <sourcemod>

#include <influx/core>
#include <influx/hud>

#undef REQUIRE_PLUGIN
#include <influx/help>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - HUD | Hide HUD",
    description = "Hide HUD elements.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    RegConsoleCmd( "sm_timer", Cmd_Timer, "Toggle timer." );
    RegConsoleCmd( "sm_sidebar", Cmd_Sidebar, "Toggle sidebar." );
    
    RegConsoleCmd( "sm_hidehud", Cmd_Settings );
    RegConsoleCmd( "sm_togglehud", Cmd_Settings );
}

public void Influx_OnRequestHUDMenuCmds()
{
    Influx_AddHUDMenuCmd( "sm_hidehud", "Toggle HUD Elements" );
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "timer", "Toggle timer." );
    Influx_AddHelpCommand( "sidebar", "Toggle sidebar." );
}

public Action Cmd_Settings( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int hideflags = Influx_GetClientHideFlags( client );
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "Hide Elements:\n " );
    
    menu.AddItem( "sm_timer",   ( hideflags & HIDEFLAG_TIMER )        ? "Timer: OFF" : "Timer: ON" );
    
    menu.AddItem( "sm_sidebar", ( hideflags & HIDEFLAG_SIDEBAR )      ? "Sidebar: OFF" : "Sidebar: ON" );
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_Timer( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int hideflags = Influx_GetClientHideFlags( client );
    
    if ( hideflags & HIDEFLAG_TIMER )
    {
        hideflags &= ~HIDEFLAG_TIMER;
    }
    else
    {
        hideflags |= HIDEFLAG_TIMER;
    }
    
    Influx_SetClientHideFlags( client, hideflags );
    
    
    Influx_PrintToChat( _, client, "Your timer is now {MAINCLR1}%s{CHATCLR}!", ( hideflags & HIDEFLAG_TIMER ) ? "hidden" : "visible" );
    
    return Plugin_Handled;
}

public Action Cmd_Sidebar( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int hideflags = Influx_GetClientHideFlags( client );
    
    if ( hideflags & HIDEFLAG_SIDEBAR )
    {
        hideflags &= ~HIDEFLAG_SIDEBAR;
    }
    else
    {
        hideflags |= HIDEFLAG_SIDEBAR;
    }
    
    Influx_SetClientHideFlags( client, hideflags );
    
    
    Influx_PrintToChat( _, client, "Your sidebar is now {MAINCLR1}%s{CHATCLR}!", ( hideflags & HIDEFLAG_SIDEBAR ) ? "hidden" : "visible" );
    
    return Plugin_Handled;
}

public int Hndlr_Settings( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    FakeClientCommand( client, szInfo );
    FakeClientCommand( client, "sm_hidehud" );
    
    return 0;
}