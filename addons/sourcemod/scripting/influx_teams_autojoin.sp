#include <sourcemod>

#include <influx/core>
//#include <influx/teams>


ConVar g_ConVar_Delay;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Autojoin Team",
    description = "Puts you in a team when connected.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    g_ConVar_Delay = CreateConVar( "influx_teams_autojoin_delay", "1", "How long we wait before autojoining a team.", FCVAR_NOTIFY, true, 0.1, true, 1337.0 );
    
    AutoExecConfig( true, "teams_autojoin", "influx" );
}

public void OnClientPutInServer( int client )
{
    CreateTimer( g_ConVar_Delay.FloatValue, T_Spawn, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
}

public Action T_Spawn( Handle hTimer, int client )
{
    if ( (client = GetClientOfUserId( client )) )
    {
        if ( !IsPlayerAlive( client ) && !IsClientSourceTV( client ) )
        {
            SpawnPlayer( client );
        }
    }
}

stock void SpawnPlayer( int client )
{
    if ( IsPlayerAlive( client ) ) return;
    
    
    int spawns_ct, spawns_t;
    int team = Inf_GetPreferredTeam( spawns_ct, spawns_t );
    
    if ( !spawns_ct && !spawns_t )
    {
        LogError( INF_CON_PRE..."No spawnpoints, can't spawn player!" );
        return;
    }
    
    
    if ( GetClientTeam( client ) != team )
    {
        ChangeClientTeam( client, team );
    }
    
    if ( !IsPlayerAlive( client ) )
    {
        CS_RespawnPlayer( client );
    }
}
