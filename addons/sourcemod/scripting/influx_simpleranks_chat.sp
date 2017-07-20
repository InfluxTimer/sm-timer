#include <sourcemod>


#include <influx/core>
#include <influx/simpleranks>



public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Simple Ranks | Chat",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    
}

public Action OnClientSayCommand( int client, const char[] szCommand, const char[] szMsg )
{
    if ( !client ) return Plugin_Continue;
    
    if ( !IsClientInGame( client ) ) return Plugin_Continue;
    
    
    static char szRank[256];
    static char szName[MAX_NAME_LENGTH];
    static char szNewMsg[512];
    
    
    
    GetClientName( client, szName, sizeof( szName ) );
    Influx_RemoveChatColors( szName, sizeof( szName ) );
    
    
    strcopy( szNewMsg, sizeof( szNewMsg ), szMsg );
    Influx_RemoveChatColors( szNewMsg, sizeof( szNewMsg ) );
    
    Influx_GetClientSimpleRank( client, szRank, sizeof( szRank ) );
    
    if ( szRank[0] != 0 )
    {
        Influx_PrintToChatAll( PRINTFLAGS_NOPREFIX, client, "%s {TEAM}%s\x01 :  %s", szRank, szName, szNewMsg );
        
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}