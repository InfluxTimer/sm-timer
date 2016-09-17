#include <sourcemod>

#include <influx/core>
#include <influx/hud>

#undef REQUIRE_PLUGIN
#include <influx/help>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - HUD | Hide Players",
    description = "Hide players or bots.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    RegConsoleCmd( "sm_hide", Cmd_Hide, "Display hide settings." );
    RegConsoleCmd( "sm_hideplayers", Cmd_Hide );
    RegConsoleCmd( "sm_hidebots", Cmd_Hide );
}

public void Influx_OnRequestHUDMenuCmds()
{
    Influx_AddHUDMenuCmd( "sm_hide", "Hide Players/Bots" );
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "hide", "Hide players or bots." );
}

public void OnClientPutInServer( int client )
{
    // Has to be hooked to everybody.
    SDKHook( client, SDKHook_SetTransmit, E_SetTransmit_Client );
}

public void OnClientDisconnect( int client )
{
    SDKUnhook( client, SDKHook_SetTransmit, E_SetTransmit_Client );
}

public Action E_SetTransmit_Client( int ent, int client )
{
    if ( !IS_ENT_PLAYER( ent ) || client == ent ) return Plugin_Continue;
    
    // If we're spectating somebody, show them no matter what.
    if ( !IsPlayerAlive( client ) && GetClientObserverTarget( client ) == ent )
    {
        return Plugin_Continue;
    }
    
    
    if ( IsFakeClient( ent ) )
    {
        return ( Influx_GetClientHideFlags( client ) & HIDEFLAG_HIDE_BOTS ) ? Plugin_Handled : Plugin_Continue;
    }
    else
    {
        return ( Influx_GetClientHideFlags( client ) & HIDEFLAG_HIDE_PLAYERS ) ? Plugin_Handled : Plugin_Continue;
    }
}

public Action Cmd_Hide( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int hideflags = Influx_GetClientHideFlags( client );
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "Hide Settings:\n " );
    
    menu.AddItem( "", ( hideflags & HIDEFLAG_HIDE_PLAYERS ) ? "Players: OFF" : "Players: ON" );
    menu.AddItem( "", ( hideflags & HIDEFLAG_HIDE_BOTS )    ? "Bots: OFF" : "Bots: ON" );
    
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Hndlr_Settings( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    int hideflags = Influx_GetClientHideFlags( client );
    switch ( index )
    {
        case 0 :
        {
            if ( hideflags & HIDEFLAG_HIDE_PLAYERS )
            {
                hideflags &= ~HIDEFLAG_HIDE_PLAYERS;
            }
            else
            {
                hideflags |= HIDEFLAG_HIDE_PLAYERS;
            }
        }
        case 1 :
        {
            if ( hideflags & HIDEFLAG_HIDE_BOTS )
            {
                hideflags &= ~HIDEFLAG_HIDE_BOTS;
            }
            else
            {
                hideflags |= HIDEFLAG_HIDE_BOTS;
            }
        }
    }
    
    Influx_SetClientHideFlags( client, hideflags );
    
    FakeClientCommand( client, "sm_hide" );
    
    return 0;
}