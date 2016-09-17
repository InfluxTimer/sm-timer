#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include <influx/core>
#include <influx/stocks_core>

#include <msharedutil/ents>


#define COLLISION_TRIGGERONLY       2
#define COLLISION_DEFAULT           5


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - No Collision",
    description = "Disables collision on players.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    HookEvent( "player_spawn", E_PlayerSpawn );
}

public void E_PlayerSpawn( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( !client ) return;
    
    if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    
    SetEntityCollisionGroup( client, COLLISION_TRIGGERONLY );
}