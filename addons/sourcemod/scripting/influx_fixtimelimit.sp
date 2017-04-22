#include <sourcemod>
#include <cstrike>

#include <influx/core>


#define DEBUG
#define DEBUG_TIME


ConVar g_ConVar_IgnoreCond;
ConVar g_ConVar_Timelimit;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Fix Timelimit",
    description = "Fixes map changes that happen once mp_timelimit has been reached.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    g_ConVar_IgnoreCond = FindConVar( "mp_ignore_round_win_conditions" );
    
    if ( g_ConVar_IgnoreCond == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for mp_ignore_round_win_conditions!" );
    }
    
    g_ConVar_Timelimit = FindConVar( "mp_timelimit" );
    
    if ( g_ConVar_Timelimit == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for mp_timelimit!" );
    }
}

public void OnMapStart()
{
    CreateTimer( 1.0, T_CheckTime, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT );
}

public Action T_CheckTime( Handle hTimer )
{
    // We cannot change the map through round termination if mp_timelimit is <= 0
    if ( g_ConVar_Timelimit.IntValue <= 0 ) return Plugin_Continue;
    
    
    int timeleft = 1;
    
    bool bSupported = GetMapTimeLeft( timeleft );
    
#if defined DEBUG_TIME
    PrintToServer( INF_DEBUG_PRE..."Time left: %i (%s)", timeleft, bSupported ? "Supported" : "Not Supported" );
#endif
    
    if ( bSupported && timeleft < 0 )
    {
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."Timelimit reached! Ending round..." );
#endif

        g_ConVar_IgnoreCond.BoolValue = false;
        
        // Round termination requires some delay or otherwise the server will not go into intermission and change the map.
        CreateTimer( 5.0, T_EndRound, _, TIMER_FLAG_NO_MAPCHANGE );
        
        return Plugin_Stop;
    }
    
    
    return Plugin_Continue;
}

public Action T_EndRound( Handle hTimer )
{
    CS_TerminateRound( 1.337, CSRoundEnd_CTWin, true );
}