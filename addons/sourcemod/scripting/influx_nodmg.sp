#include <sourcemod>
#include <cstrike>
#include <sdktools_hooks>

#include <influx/core>
#include <influx/stocks_core>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - No Damage",
    description = "Disable players getting hurt fee fees :(",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // EVENTS
    HookEvent( "player_spawn", E_PlayerSpawn );
}

public void E_PlayerSpawn( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( !client ) return;
    
    if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    
    RequestFrame( E_PlayerSpawn_Delay, GetClientUserId( client ) );
}

public void E_PlayerSpawn_Delay( int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    if ( !IsPlayerAlive( client ) ) return;
    
    
    SetEntProp( client, Prop_Data, "m_takedamage", 1 ); // Events only so we still have stamina affecting us.
    
    
    // Crashes when seeing other players in CSGO(?).
    /*if ( !IsFakeClient( client ) )
    {
        SetEntProp( client, Prop_Send, "m_nHitboxSet", 2 );
    }*/
}