#include <sourcemod>
#include <cstrike>

#include <influx/core>
#include <influx/hud>

#undef REQUIRE_PLUGIN
#include <influx/help>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - HUD | Viewmodel",
    description = "Toggle viewmodel.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // EVENTS
    HookEvent( "player_spawn", E_PlayerSpawn );
    
    // CMDS
    RegConsoleCmd( "sm_viewmodel", Cmd_Viewmodel, "Toggle viewmodel." );
    RegConsoleCmd( "sm_vm", Cmd_Viewmodel );
}

public void Influx_OnRequestHUDMenuCmds()
{
    Influx_AddHUDMenuCmd( "sm_viewmodel", "Toggle Viewmodel" );
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "viewmodel", "Toggle viewmodel." );
}

public void E_PlayerSpawn( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( !client ) return;
    
    if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    
    if ( !IsFakeClient( client ) )
    {
        RequestFrame( E_PlayerSpawn_Delay, GetClientUserId( client ) );
    }
}

public void E_PlayerSpawn_Delay( int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    if ( !IsPlayerAlive( client ) ) return;
    
    
    SetDrawViewmodel( client, ( Influx_GetClientHideFlags( client ) & HIDEFLAG_VIEWMODEL ) ? false : true );
}

public Action Cmd_Viewmodel( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int hideflags = Influx_GetClientHideFlags( client );
    
    if ( hideflags & HIDEFLAG_VIEWMODEL )
    {
        hideflags &= ~HIDEFLAG_VIEWMODEL;
    }
    else
    {
        hideflags |= HIDEFLAG_VIEWMODEL;
    }
    
    Influx_SetClientHideFlags( client, hideflags );
    
    
    bool draw = ( hideflags & HIDEFLAG_VIEWMODEL ) ? false: true;
    
    SetDrawViewmodel( client, draw );
    
    
    Influx_PrintToChat( _, client, "Your viewmodel is now {TEAM}%s{CHATCLR}!", draw ? "visible" : "hidden" );
    
    return Plugin_Handled;
}

stock bool SetDrawViewmodel( int client, bool mode )
{
    SetEntProp( client, Prop_Data, "m_bDrawViewmodel", mode );
}