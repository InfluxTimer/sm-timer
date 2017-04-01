#include <sourcemod>

#include <influx/core>
#include <influx/teletoend>



// FORWARDS
Handle g_hForward_OnSearchEnd;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Teleport to end",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    RegPluginLibrary( INFLUX_LIB_TELETOEND );
}

public void OnPluginStart()
{
    // FORWARDS
    g_hForward_OnSearchEnd = CreateGlobalForward( "Influx_OnSearchEnd", ET_Hook, Param_Cell, Param_Array );
    
    
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
    if ( SearchEnd( runid, pos ) )
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
    Action res = Plugin_Continue;
    
    Call_StartForward( g_hForward_OnSearchEnd );
    Call_PushCell( runid );
    Call_PushArrayEx( pos, 3, SM_PARAM_COPYBACK );
    Call_Finish( res );
    
    
    return ( res != Plugin_Continue );
}