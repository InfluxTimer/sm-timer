public void E_PlayerSpawn( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( !client ) return;
    
    if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    
    TeleClientToStart_Safe( client, g_iRunId[client] );
}

public void E_ConVarChanged_DefMode( ConVar convar, const char[] oldValue, const char[] newValue )
{
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Default mode change... (%s)", newValue );
#endif

    Search_t search = SEARCH_INVALID;
    int value;
    
    SearchType( newValue, search, value );
    
    if ( search != SEARCH_MODE )
    {
        LogError( INF_CON_PRE..."Invalid default mode '%s'!", newValue );
        return;
    }
    
    g_iDefMode = value;
}

public void E_ConVarChanged_DefStyle( ConVar convar, const char[] oldValue, const char[] newValue )
{
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Default style change... (%s)", newValue );
#endif

    Search_t search = SEARCH_INVALID;
    int value;
    
    SearchType( newValue, search, value );
    
    if ( search != SEARCH_STYLE )
    {
        LogError( INF_CON_PRE..."Invalid default style '%s'!", newValue );
        return;
    }
    
    g_iDefStyle = value;
}