#include <sourcemod>
#include <cstrike>

#include <influx/core>



public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Disable Round Restart",
    description = "Disables game start round restart. mp_ignore_round_win_conditions 1 is still needed!",
    version = INF_VERSION
};

public Action CS_OnTerminateRound( float& delay, CSRoundEndReason& reason )
{
    if ( reason == CSRoundEnd_GameStart )
    {
        LogMessage( INF_CON_PRE..."Blocking game start round restart." );
        return Plugin_Handled;
    }

    return Plugin_Continue;
}
