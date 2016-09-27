#include <sourcemod>

#include <influx/core>

#include <standup/core>
#include <standup/ljmode>

#undef REQUIRE_PLUGIN
#include <influx/hud>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Compatibility | Standup",
    description = "Compatibility with Standup LJ plugin",
    version = INF_VERSION
};

public Action Influx_ShouldDrawHUD( int client, int target, HudType_t hudtype )
{
    return (/*hudtype == HUDTYPE_HINT
    &&*/      Standup_IsClientStatsEnabled( target )
    /*&&      Standup_GetClientNextHint( target ) < GetEngineTime()*/ ) ? Plugin_Stop : Plugin_Continue;
}

public void Influx_OnClientModeChangePost( int client, int mode )
{
    if ( mode != MODE_SCROLL && Standup_IsClientStatsEnabled( client ) )
    {
        Standup_SetClientStats( client, false );
    }
}

public Action Standup_OnStatsEnable( int client, char[] szMsg, int msg_len )
{
    if ( Influx_GetClientMode( client ) != MODE_SCROLL )
    {
        Influx_SetClientMode( client, MODE_SCROLL );
    }
    
    // Make sure we've set it.
    if ( Influx_GetClientMode( client ) != MODE_SCROLL )
    {
        strcopy( szMsg, msg_len, "Your mode must be Scroll to use longjump stats!" );
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}