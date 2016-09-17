#include <sourcemod>
#include <cstrike>

#include <influx/core>


// CONVARS
ConVar g_ConVar_Type;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Disable Suicide",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CONVARS
    g_ConVar_Type = CreateConVar( "influx_disablesuicide_type", "1", "0 = Allow suicide, 1 = Change to spectator team, 2 = Teleport to start, 3 = Don't do anything, just block.", FCVAR_NOTIFY, true, 0.0, true, 3.0 );
    
    AutoExecConfig( true, "disablesuicide", "influx" );
    
    
    // LISTENERS
    AddCommandListener( Lstnr_Kill, "kill" );
    AddCommandListener( Lstnr_Kill, "explode" );
}

public Action Lstnr_Kill( int client, const char[] command, int argc )
{
    if ( !client ) return Plugin_Continue;
    
    
    switch ( g_ConVar_Type.IntValue )
    {
        case 0 : return Plugin_Continue;
        case 1 : ChangeClientTeam( client, CS_TEAM_SPECTATOR );
        case 2 : FakeClientCommand( client, "sm_restart" );
    }
    
    return Plugin_Handled;
}