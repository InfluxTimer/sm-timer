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
    float srtime = Influx_GetClientLastCPSRTime( client );
    
    
    decl String:szSR[32];
    decl String:szSRDif[32];
    
    int c[2];
    
    decl String:szBestTotal[128];
    szBestTotal[0] = '\0';
    
    
    if ( besttime != srtime )
    {
        decl String:szBest[32];
        decl String:szBestDif[32];
        
        Inf_FormatSeconds( besttime, szBest, sizeof( szBest ) );
        
        Inf_FormatSeconds( Inf_GetTimeDif( time, besttime, c[0] ), szBestDif, sizeof( szBestDif ) );
        Format( szBestDif, sizeof( szBestDif ), "{%s}%c%s{CHATCLR}", ( c[0] == '-' ) ? "LIGHTRED" : "GREEN",  c[0], szBestDif );
        
        FormatEx( szBestTotal, sizeof( szBestTotal ), ", {MAINCLR1}BEST: %s{CHATCLR} (%s)",
            szBest,
            szBestDif );
    }
    
    
    
    Inf_FormatSeconds( srtime, szSR, sizeof( szSR ) );
    
    Inf_FormatSeconds( Inf_GetTimeDif( time, srtime, c[1] ), szSRDif, sizeof( szSRDif ) );
    Format( szSRDif, sizeof( szSRDif ), "{%s}%c%s{CHATCLR}", ( c[1] == '-' ) ? "LIGHTRED" : "GREEN", c[1], szSRDif );
    
    
    Influx_PrintToChatEx( _, client, clients, nClients, "CP %i | {MAINCLR1}SR: %s{CHATCLR} (%s)%s",
        cpnum,
        szSR,
        szSRDif,
        szBestTotal );
}

stock float Inf_GetTimeDif( float time, float compare_time, int &c )
{
    decl Float:dif;
    
    if ( time > compare_time )
    {
        dif = time - compare_time;
        c = '+';
    }
    else
    {
        dif = compare_time - time;
        c = '-';
    }
    
    return dif;
}