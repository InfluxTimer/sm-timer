#include <sourcemod>

#include <influx/core>
#include <influx/hud>


//#define DEBUG


int g_iLastShot[INF_MAXPLAYERS];

bool g_bIsGO;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Hide Players | Weapon Sounds",
    description = "Disable weapon sounds also.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    g_bIsGO = GetEngineVersion() == Engine_CSGO;
    
    
    AddTempEntHook( "Shotgun Shot", E_ShotgunShot );
}

public void OnClientPutInServer( int client )
{
    g_iLastShot[client] = 0;
}

public Action E_ShotgunShot( const char[] te_name, const int[] Players, int numClients, float delay )
{
    // Apparently it's not the index. For some weird reason.
    int player = TE_ReadNum( "m_iPlayer" ) + 1;
    
    if ( !IS_ENT_PLAYER( player ) ) return Plugin_Continue;
    
    if ( !IsClientInGame( player ) ) return Plugin_Continue;
    
    
    // We've already processed this shot!
    if ( g_iLastShot[player] == GetGameTickCount() )
    {
        return Plugin_Continue;
    }
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Shots fired by %i! (tick: %i)", player, GetGameTickCount() );
#endif
    
    g_iLastShot[player] = GetGameTickCount();
    
    
    // What flag to check against.
    int flag = IsFakeClient( player ) ? HIDEFLAG_HIDE_BOTS : HIDEFLAG_HIDE_PLAYERS;
    
    
    int nClients = 0;
    int[] clients = new int[MaxClients];
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) ) continue;
        
        if ( IsFakeClient( i ) ) continue;
        
        // Would play the sound twice.
        if ( i == player ) continue;
        
        
        
        if ((!IsPlayerAlive( i ) && GetClientObserverTarget( i ) == player) // That's our spectator target!
        ||  !(Influx_GetClientHideFlags( i ) & flag)) // We don't want to hide!
        {
            clients[nClients++] = i;
        }
    }
    
    // Nothing changed.
    if ( nClients == numClients ) return Plugin_Continue;
    
    
    if ( nClients )
    {
        decl Float:temp[3];
        
        TE_Start( "Shotgun Shot" );
        
        TE_ReadVector( "m_vecOrigin", temp );
        TE_WriteVector( "m_vecOrigin", temp );
        TE_WriteFloat( "m_vecAngles[0]", TE_ReadFloat( "m_vecAngles[0]" ) );
        TE_WriteFloat( "m_vecAngles[1]", TE_ReadFloat( "m_vecAngles[1]" ) );
        
        if ( g_bIsGO )
            TE_WriteNum( "m_weapon", TE_ReadNum( "m_weapon" ) ); // Thanks Valve...
        else
            TE_WriteNum( "m_iWeaponID", TE_ReadNum( "m_iWeaponID" ) );
        
        TE_WriteNum( "m_iMode", TE_ReadNum( "m_iMode" ) );
        TE_WriteNum( "m_iSeed", TE_ReadNum( "m_iSeed" ) );
        TE_WriteNum( "m_iPlayer", player - 1 );
        TE_WriteFloat( "m_fInaccuracy", TE_ReadFloat( "m_fInaccuracy" ) );
        TE_WriteFloat( "m_fSpread", TE_ReadFloat( "m_fSpread" ) );
        
        TE_Send( clients, nClients, delay );
    }
    
    return Plugin_Stop;
}