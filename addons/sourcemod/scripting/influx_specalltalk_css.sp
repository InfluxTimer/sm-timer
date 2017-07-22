#include <sourcemod>
#include <cstrike>

#include <influx/core>
#include <influx/stocks_chat>


//#define DEBUG
//#define TEST


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Spectator All Talk (CSS)",
    description = "Lets spectators chat with other players. (use sv_full_alltalk 1 with CS:GO)",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    if ( GetEngineVersion() != Engine_CSS )
    {
        FormatEx( szError, error_len, "Bad engine version!" );
        
        return APLRes_SilentFailure;
    }
    
    return APLRes_Success;
}

public void OnPluginStart()
{
#if defined TEST
    RegConsoleCmd( "sm_test_specalltalk", Cmd_Test );
#endif
}

#if defined TEST
public Action Cmd_Test( int client, int args )
{
    int bot = 0;
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) ) continue;
        
        if ( IsFakeClient( i ) )
        {
            bot = i;
            break;
        }
    }
    
    if ( !bot ) return Plugin_Handled;
    
    
    if ( GetClientTeam( bot ) != CS_TEAM_SPECTATOR )
    {
        ChangeClientTeam( bot, CS_TEAM_SPECTATOR );
    }
    
    
    
    FakeClientCommand( bot, "say Hello, I'm a spectator!" );
    
    return Plugin_Handled;
}
#endif

public void OnClientSayCommand_Post( int client, const char[] szCommand, const char[] szMsg )
{
    if ( !client ) return;
    
    if ( !IsClientInGame( client ) ) return;
    
    if ( GetClientTeam( client ) != CS_TEAM_SPECTATOR ) return;
    
    
    int nClients = 0;
    int[] clients = new int[MaxClients];
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) ) continue;
        
        if ( IsFakeClient( i ) ) continue;
        
        if ( i == client ) continue;
        
        if ( GetClientTeam( i ) == CS_TEAM_SPECTATOR ) continue;
        
        
        clients[nClients++] = i;
    }
    
    if ( !nClients ) return;
    
    
    static char szNewMsg[512];
    
    decl String:szName[MAX_NAME_LENGTH];
    GetClientName( client, szName, sizeof( szName ) );
    
    FormatEx( szNewMsg, sizeof( szNewMsg ), "*SPEC* \x03%s\x01 :  %s", szName, szMsg );
    
    Inf_SendSayText2( client, clients, nClients, szNewMsg );
    
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Re-sent spectator msg to %i clients! (%s)", nClients, szMsg );
#endif
}