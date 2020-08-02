#include <sourcemod>

#include <influx/core>
#include <influx/zones_checkpoint>

#include <msharedutil/ents>

#undef REQUIRE_PLUGIN
#include <influx/hud>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Print CP Times",
    description = "Displays current checkpoint times in chat.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    LoadTranslations( INFLUX_PHRASES );
}


public void Influx_OnClientCPSavePost( int client, int cpnum )
{
    int[] clients = new int[MaxClients];
    int nClients = 0;
    
    bool allow;
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) ) continue;
        
        if ( IsFakeClient( i ) ) continue;
        
        
        if (i == client
        ||  (!IsPlayerAlive( i ) && GetClientObserverTarget( i ) == client) )
        {
            allow = true;
        }
        else
        {
            allow = false;
        }
        
        
        if ( allow )
        {
            clients[nClients++] = i;
        }
    }
    
    if ( !nClients ) return;
    
    
    
    float time = Influx_GetClientLastCPTime( client );
    
    float besttime = Influx_GetClientLastCPBestTime( client );
    float pbtime = Influx_GetClientLastCPPBTime( client );
    float srtime = Influx_GetClientLastCPSRTime( client );
    
    
    
    int c;
    
    decl String:szBest[128];
    szBest[0] = '\0';
    
    decl String:szSR[128];
    szSR[0] = '\0';
    
    decl String:szPB[128];
    szPB[0] = '\0';
    
    decl String:szTime[32];
    decl String:szTimeDif[32];

    
    
    if ( srtime != INVALID_RUN_TIME )
    {
        Inf_FormatSeconds( srtime, szTime, sizeof( szTime ) );
        Inf_FormatSeconds( Inf_GetTimeDif( time, srtime, c ), szTimeDif, sizeof( szTimeDif ) );
        
        FormatEx( szSR, sizeof( szSR ), "%T", "INF_CP_SR", LANG_SERVER, szTime, c, szTimeDif );
    }
    
    if ( pbtime != INVALID_RUN_TIME )
    {
        Inf_FormatSeconds( pbtime, szTime, sizeof( szTime ) );
        Inf_FormatSeconds( Inf_GetTimeDif( time, pbtime, c ), szTimeDif, sizeof( szTimeDif ) );
        
        FormatEx( szPB, sizeof( szPB ), "%T", "INF_CP_PB", LANG_SERVER, szTime, c, szTimeDif );
    }
    
    if ( besttime != INVALID_RUN_TIME && besttime != srtime )
    {
        Inf_FormatSeconds( besttime, szTime, sizeof( szTime ) );
        Inf_FormatSeconds( Inf_GetTimeDif( time, besttime, c ), szTimeDif, sizeof( szTimeDif ) );
        
        FormatEx( szBest, sizeof( szBest ), "%T", "INF_CP_BEST", LANG_SERVER, szTime, c, szTimeDif );
    }
    
    
    // Print if we have something to print!
    if ( szSR[0] != '\0' || szPB[0] != '\0' || szBest[0] != '\0' )
    {
        for( int i; i < nClients; i++ )
            if( clients[i] && IsClientInGame( clients[i] ) )
                Influx_PrintToChat( 
                    clients[i],
                    "%T", "INF_CP_PRINT", LANG_SERVER,
                    cpnum,
                    szSR,
                    ( szSR[0] && szPB[0] ) ? " | " : "",
                    szPB,
                    ( (szSR[0] || szPB[0]) && szBest[0] ) ? " | " : "",
                    szBest
                );
    }
}
