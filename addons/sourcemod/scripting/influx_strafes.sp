#include <sourcemod>

#include <influx/core>
#include <influx/stocks_strf>
#include <influx/strafes>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>

#undef REQUIRE_PLUGIN
#include <influx/recordsmenu>
#include <influx/pause>


//#define DEBUG_SURF


int g_nNumStrfs[INF_MAXPLAYERS];
bool g_bCount[INF_MAXPLAYERS];


// FORWARDS
Handle g_hForward_ShouldCountStrafes;


// LIBRARIES
bool g_bLib_Pause;


bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Strafes",
    description = "Counts strafes and saves them to database",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    RegPluginLibrary( INFLUX_LIB_STRAFES );
    
    // NATIVES
    CreateNative( "Influx_GetClientStrafeCount", Native_GetClientStrafeCount );
    CreateNative( "Influx_IsCountingStrafes", Native_IsCountingStrafes );
    
    
    g_bLate = late;
}

public void OnPluginStart()
{
    // FORWARDS
    g_hForward_ShouldCountStrafes = CreateGlobalForward( "Influx_ShouldCountStrafes", ET_Hook, Param_Cell );
    
    
    // LIBRARIES
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
    
    
    if ( g_bLate )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) )
            {
                OnClientPutInServer( i );
            }
        }
    }
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = false;
}

public void OnClientPutInServer( int client )
{
    g_bCount[client] = false;
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    Action res = Plugin_Continue;
    
    Call_StartForward( g_hForward_ShouldCountStrafes );
    Call_PushCell( client );
    Call_Finish( res );
    
    if ( res == Plugin_Continue )
    {
        g_bCount[client] = true;
        HookThinks( client );
    }
    else
    {
        g_bCount[client] = false;
        UnhookThinks( client );
    }
    
    g_nNumStrfs[client] = g_bCount[client] ? 0 : -1;
}

public void OnAllPluginsLoaded()
{
    Handle db = Influx_GetDB();
    
    if ( db == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    }
    
    
    SQL_TQuery( db, Thrd_Empty, "ALTER TABLE "...INF_TABLE_TIMES..." ADD COLUMN strf_num INTEGER DEFAULT -1", _, DBPrio_High );
}

public void Thrd_Empty( Handle db, Handle res, const char[] szError, any data ) {}


public void Influx_OnPrintRecordInfo( int client, Handle dbres, ArrayList itemlist, Menu menu, int uid, int mapid, int runid, int mode, int style )
{
    decl field;
    if ( SQL_FieldNameToNum( dbres, "strf_num", field ) )
    {
        int numstrfs = SQL_FetchInt( dbres, field );
        
        if ( numstrfs >= 0 )
        {
            decl String:szItem[64];
            FormatEx( szItem, sizeof( szItem ), "Strafes: %i", numstrfs );
            
            itemlist.PushString( szItem );
        }
    }
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    if ( flags & RES_TIME_FIRSTOWNREC && !g_bCount[client] ) return;
    
    
    if ( flags & (RES_TIME_PB | RES_TIME_FIRSTOWNREC) )
    {
        Handle db = Influx_GetDB();
        if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
        
        
        decl String:szQuery[192];
        FormatEx( szQuery, sizeof( szQuery ), "UPDATE "...INF_TABLE_TIMES..." SET strf_num=%i WHERE uid=%i AND mapid=%i AND runid=%i AND mode=%i AND style=%i",
            g_nNumStrfs[client],
            Influx_GetClientId( client ),
            Influx_GetCurrentMapId(),
            runid,
            mode,
            style );
        
        SQL_TQuery( db, Thrd_Update, szQuery, GetClientUserId( client ), DBPrio_Normal );
    }
}

public void Thrd_Update( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "updating player's record with strafes", GetClientOfUserId( client ), "Couldn't record your strafes!" );
    }
}

public void E_PostThinkPost_Client( int client )
{
    if ( !IsPlayerAlive( client ) ) return;
    
    if ( !g_bCount[client] )
    {
        UnhookThinks( client );
        return;
    }
    
    static Strafe_t iLastValidStrafe[INF_MAXPLAYERS];
    
    static float flLastLand[INF_MAXPLAYERS];
    static int fLastFlags[INF_MAXPLAYERS];
    
    static float prevvel[INF_MAXPLAYERS][3];
    static float prevyaw[INF_MAXPLAYERS];
    
    
    
    static float vel[3], angles[3];
    GetEntityVelocity( client, vel );
    GetClientEyeAngles( client, angles );

    
    int flags = GetEntityFlags( client );
    
    
    
    if ( !(fLastFlags[client] & FL_ONGROUND) && flags & FL_ONGROUND )
    {
        flLastLand[client] = GetEngineTime();
    }
    
    
    // Ignore completely if we're not running or we are paused.
    if (Influx_GetClientState( client ) != STATE_RUNNING
    ||  (g_bLib_Pause && Influx_IsClientPaused( client )))
    {
        iLastValidStrafe[client] = STRF_INVALID;
    }
    else if (   !(flags & FL_ONGROUND) ||
                (flags & FL_ONGROUND && (GetEngineTime() - flLastLand[client]) < 0.05) ) // Have we been landed only for a short period of time?
    {
        // Alright, we are in air.
        // Check which direction we are going relative to our previous direction.
        float delta = GetVectorsAngle( prevvel[client], vel );
        
        if ( delta != 0.0 )
        {
            Strafe_t velstrafe = ( delta > 0.0 ) ? STRF_LEFT: STRF_RIGHT;
            
            
            static float base[3];
            GetEntityBaseVelocity( client, base );
            
            // Don't count if we're affected by push triggers.
            if (base[0] > -0.1 && base[0] < 0.1
            &&  base[1] > -0.1 && base[1] < 0.1)
            {
                Strafe_t lookstrf = GetStrafe( angles[1], prevyaw[client] );
                
                // Our strafes must be the same but not the same as last time.
                if (velstrafe != iLastValidStrafe[client]
                &&  lookstrf == velstrafe)
                {
                    // Trace down to check for invalid surfaces.
                    bool valid = true;
                    
                    decl Float:start[3], Float:end[3];
                    GetClientAbsOrigin( client, start );
                    
                    end = start;
                    
                    end[2] -= 4.0;
                    start[2] += 4.0;
                    
#define TRACE_MINS      view_as<float>( { -16.0, -16.0, 0.0 } )
#define TRACE_MAXS      view_as<float>( { 16.0, 16.0, 0.0 } )
                    
                    TR_TraceHullFilter( start, end, TRACE_MINS, TRACE_MAXS, MASK_PLAYERSOLID, TraceFilter_AnythingButMe, client );
                    
                    if ( TR_DidHit() )
                    {
                        decl Float:normal[3];
                        TR_GetPlaneNormal( null, normal );
                        
#if defined DEBUG_SURF
                        if ( normal[2] != 1.0 )
                        {
                            PrintToServer( INF_DEBUG_PRE..."Client %i | Normal: {%.2f, %.2f, %.2f}",
                                client,
                                normal[0],
                                normal[1],
                                normal[2] );
                        }
#endif
                        // We're on a surf platform or sliding...
                        if ( normal[2] <= 0.65 )
                        {
                            valid = false;
                        }
                    }
                    
                    if ( valid )
                    {
                        ++g_nNumStrfs[client];
                        iLastValidStrafe[client] = velstrafe;
                    }
                }
            }
        }
    }
    else if ( flags & FL_ONGROUND )
    {
        // Reset our last strafe if we've been on the ground for too long.
        iLastValidStrafe[client] = STRF_INVALID;
    }
    
    prevyaw[client] = angles[1];
    prevvel[client] = vel;
    fLastFlags[client] = flags;
}

public bool TraceFilter_AnythingButMe( int ent, int mask, int client )
{
    return ( ent != client );
}

stock void HookThinks( int client )
{
    Inf_SDKHook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
}

stock void UnhookThinks( int client )
{
    SDKUnhook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
}

public int Native_GetClientStrafeCount( Handle hPlugin, int nParams )
{
    return g_nNumStrfs[GetNativeCell( 1 )];
}

public int Native_IsCountingStrafes( Handle hPlugin, int nParams )
{
    return g_bCount[GetNativeCell( 1 )];
}