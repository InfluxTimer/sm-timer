#include <sourcemod>

#include <influx/core>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Teleport to end",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_end", Cmd_GotoEnd );
    RegConsoleCmd( "sm_goend", Cmd_GotoEnd );
    RegConsoleCmd( "sm_gotoend", Cmd_GotoEnd );
    RegConsoleCmd( "sm_teletoend", Cmd_GotoEnd );
    RegConsoleCmd( "sm_teleend", Cmd_GotoEnd );
}

public Action Cmd_GotoEnd( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    
    int runid = Influx_GetClientRunId( client );
    
    int irun = Influx_FindRunById( runid );
    if ( irun == -1 ) return Plugin_Handled;
    
    
    float pos[3];
    float yaw = 0.0;
    if ( Influx_SearchTelePos( pos, yaw, runid, TELEPOSTYPE_END ) )
    {
        Influx_SetClientState( client, STATE_NONE );
        
        TeleportEntity( client, pos, NULL_VECTOR, NULL_VECTOR );
    }
    else
    {
        char szRun[MAX_RUN_NAME];
        Influx_GetRunName( runid, szRun, sizeof( szRun ) );
        
        
        Influx_PrintToChat( _, client, "Couldn't find end to {MAINCLR1}%s{CHATCLR}!", szRun );
    }
    
    return Plugin_Handled;
}

stock bool SearchEnd( int runid, float pos[3] )
{
    return ;
}