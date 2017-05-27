#include <sourcemod>

#include <influx/core>

#include <standup/core>
#include <standup/ljmode>

#undef REQUIRE_PLUGIN
#include <influx/hud_draw>


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
    return (/*hudtype == HUDTYPE_TIMER
    &&*/      Standup_IsClientStatsEnabled( target )
    /*&&      Standup_GetClientNextHint( target ) < GetEngineTime()*/ ) ? Plugin_Stop : Plugin_Continue;
}

public void Influx_OnClientModeChangePost( int client, int mode, int lastmode )
{
    if ( mode != MODE_SCROLL && Standup_IsClientStatsEnabled( client ) )
    {
        Standup_SetClientStats( client, false );
    }
}

public void Influx_OnClientStyleChangePost( int client, int style, int laststyle )
{
    if ( style != STYLE_NORMAL && Standup_IsClientStatsEnabled( client ) )
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
    
    if ( Influx_GetClientStyle( client ) != STYLE_NORMAL )
    {
        Influx_SetClientStyle( client, STYLE_NORMAL );
    }
    
    // Make sure we've set it.
    if ( Influx_GetClientMode( client ) != MODE_SCROLL )
    {
        strcopy( szMsg, msg_len, "Your mode must be Scroll to use longjump stats!" );
        return Plugin_Handled;
    }
    
    if ( Influx_GetClientStyle( client ) != STYLE_NORMAL )
    {
        strcopy( szMsg, msg_len, "Your style must be Normal to use longjump stats!" );
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}