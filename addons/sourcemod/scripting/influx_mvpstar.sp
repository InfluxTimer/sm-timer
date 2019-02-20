#include <sourcemod>
#include <cstrike>

#include <influx/core>

#undef REQUIRE_PLUGIN
#include <influx/maprankings>



//#define DEBUG


#define MVPTYPE_MAPSBEATEN          1
#define MVPTYPE_MAPSBEATENMAIN      2
#define MVPTYPE_TOPRECS             3
#define MVPTYPE_RUNRANK             4


// CONVARS
ConVar g_ConVar_Type;




bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - MVP Star",
    description = "The stars found on the scoreboard will be used to signify things. (amount of maps beaten, etc.)",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    g_bLate = late;
}

public void OnPluginStart()
{
    // CONVARS
    g_ConVar_Type = CreateConVar( "influx_mvpstar_type", "2", "1 = Maps beaten, 2 = Maps beaten (main only), 3 = Amount of top records, 4 = Map ranking | Else disabled.", FCVAR_NOTIFY );
    
    AutoExecConfig( true, "mvpstar", "influx" );
    
    
    
    if ( g_bLate )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            // Query for clients who have an id.
            if ( IsClientInGame( i ) && !IsFakeClient( i ) && Influx_GetClientId( i ) > 0 )
            {
                InitClientStars( i, true );
            }
        }
    }
}

public void Influx_OnClientRankingsCached( int client )
{
    if ( GetMVPType() == MVPTYPE_RUNRANK )
    {
        InitClientStars( client, true );
    }
}

public void Influx_OnClientIdRetrieved( int client, int uid, bool bNew )
{
    InitClientStars( client );
}

stock void PostStatusChanged( int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) )
        return;
    
    
    SetStars( client, Influx_GetClientCurrentMapRank( client ) );
}

public void Influx_OnClientStatusChanged( int client )
{
    if ( GetMVPType() == MVPTYPE_RUNRANK )
    {
        // We need to wait, because our rank plugin uses this forward to set the rank. 
        RequestFrame( PostStatusChanged, GetClientUserId( client ) );
    }
}

stock void InitClientStars( int client, bool bIsLate = false )
{
    switch ( GetMVPType() )
    {
        case MVPTYPE_MAPSBEATEN : DB_MapsBeaten( client, false );
        case MVPTYPE_MAPSBEATENMAIN : DB_MapsBeaten( client, true );
        case MVPTYPE_TOPRECS : DB_TopRecords( client );
        case MVPTYPE_RUNRANK :
        {
            if ( bIsLate )
                Influx_OnClientStatusChanged( client );
        }
    }
}

stock void DB_MapsBeaten( int client, bool bMainOnly = true )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    int uid = Influx_GetClientId( client );
    
    
    static char szWhere[128];
    szWhere[0] = 0;
    if ( bMainOnly )
    {
        FormatEx( szWhere, sizeof( szWhere ), "runid=%i AND ", MAIN_RUN_ID );
    }
    
    
    static char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT COUNT(*) " ...
        "FROM "...INF_TABLE_TIMES..." WHERE %suid=%i " ...
        "GROUP BY uid,mapid",
        szWhere,
        uid );
    
    
    SQL_TQuery( db, Thrd_Result, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_TopRecords( int client )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    int uid = Influx_GetClientId( client );
    
    
    static char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT COUNT(*) FROM " ...
        "(" ...
        "SELECT uid FROM "...INF_TABLE_TIMES..." AS _t WHERE runid=%i AND uid=%i AND rectime=" ...
        "(SELECT MIN(rectime) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style LIMIT 1)" ...
        ") AS _sub",
        MAIN_RUN_ID,
        uid );
    
    
    SQL_TQuery( db, Thrd_Result, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

public void Thrd_Result( Handle db, Handle res, const char[] szError, int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "getting client MVP star count" );
        return;
    }
    
    
    if ( SQL_FetchRow( res ) )
    {
        SetStars( client, SQL_FetchInt( res, 0 ) );
    }
    else
    {
        SetStars( client, 0 );
    }
}

stock int SetStars( int client, int realstars )
{
    int stars = realstars > 0 ? realstars : 0;
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Setting %N's mvp stars to %i (real: %i)", client, stars, realstars );
#endif
    
    CS_SetMVPCount( client, stars );
}

stock int GetMVPType()
{
    return g_ConVar_Type.IntValue;
}
