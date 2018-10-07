#include <sourcemod>


#include <influx/core>
#include <influx/simpleranks>
#include <influx/simpleranks_chat>

#undef REQUIRE_PLUGIN
#include <influx/silent_chatcmds>
#include <basecomm>


bool g_bLib_BaseComm;
bool g_bLib_SilentChatCmds;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Simple Ranks | Chat",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_SIMPLERANKS_CHAT );
}

public void OnPluginStart()
{
    // LIBRARIES
    g_bLib_BaseComm = LibraryExists( "basecomm" );
    g_bLib_SilentChatCmds = LibraryExists( INFLUX_LIB_SILENT_CHATCMDS );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, "basecomm" ) ) g_bLib_BaseComm = true;
    if ( StrEqual( lib, INFLUX_LIB_SILENT_CHATCMDS ) ) g_bLib_SilentChatCmds = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, "basecomm" ) ) g_bLib_BaseComm = false;
    if ( StrEqual( lib, INFLUX_LIB_SILENT_CHATCMDS ) ) g_bLib_SilentChatCmds = false;
}

public Action OnClientSayCommand( int client, const char[] szCommand, const char[] szMsg )
{
    if ( !client ) return Plugin_Continue;
    
    if ( !IsClientInGame( client ) ) return Plugin_Continue;
    
    // Gagged?
    if ( g_bLib_BaseComm && BaseComm_IsClientGagged( client ) )
    {
        return Plugin_Handled;
    }
    
    // This message should be silenced.
    if ( g_bLib_SilentChatCmds && IsChatTrigger() && Influx_ShouldSilenceCmd( szMsg ) )
    {
        return Plugin_Handled;
    }
    
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
