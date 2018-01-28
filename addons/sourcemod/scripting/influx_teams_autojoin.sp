#include <sourcemod>

#include <influx/core>
#include <influx/teams>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Autojoin Team",
    description = "Puts you in a team when connected.",
    version = INF_VERSION
};

public void OnClientPutInServer( int client )
{
    CreateTimer( 1.0, T_Spawn, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
}

public Action T_Spawn( Handle hTimer, int client )
{
    if ( (client = GetClientOfUserId( client )) )
    {
        if ( !IsPlayerAlive( client ) && !IsClientSourceTV( client ) )
        {
            Influx_SpawnPlayer( client );
        }
    }
}