#include <sourcemod>

#include <influx/core>
#include <influx/strfsync>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>

#undef REQUIRE_PLUGIN
#include <influx/pause>



//#define DEBUG

#define NUM_SECS            60


int g_nStrfsGood[INF_MAXPLAYERS][NUM_SECS];
int g_iStrfPos[INF_MAXPLAYERS];
int g_nTickCount[INF_MAXPLAYERS];
bool g_bUsedAll[INF_MAXPLAYERS];


// 1 second worth of ticks.
int g_nMaxTicks;


// LIBRARIES
bool g_bLib_Pause;

bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Strafe Sync",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    RegPluginLibrary( INFLUX_LIB_STRFSYNC );
    
    // NATIVES
    CreateNative( "Influx_GetClientStrafeSync", Native_GetClientStrafeSync );
    
    
    g_bLate = late;
}

public void OnPluginStart()
{
    g_nMaxTicks = RoundFloat( 1.0 / GetTickInterval() );
    
    
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
    ResetClient( client );
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    ResetClient( client );
}

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3] )
{
    static int fLastFlags[INF_MAXPLAYERS];
    static float flLastYaw[INF_MAXPLAYERS];
    
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
    
    
    if ( IS_PAUSED( g_bLib_Pause, client ) ) return Plugin_Continue;
    
    
    int flags = GetEntityFlags( client );
    

    
    if (!(flags & FL_ONGROUND)
    &&  !(fLastFlags[client] & FL_ONGROUND)
    &&  flLastYaw[client] != angles[1])
    {
        if ( (vel[0] != 0.0 || vel[1] != 0.0) )
        {
            decl Float:temp[3];
            temp = vel;
            
            float yaw = angles[1];
            
            
            
            RotateVectorXY( temp, DegToRad( yaw ) );
            
            
            decl Float:velocity[3];
            GetEntityAbsVelocity( client, velocity );
            
            
            GetUnitVectorXY( temp, temp );
            //GetUnitVectorXY( velocity, velocity );
            
            temp[2] = 0.0;
            velocity[2] = 0.0;
            
            float dot = GetVectorDotProduct( temp, velocity );
            
            if ( dot < 30.0 )
            {
                ++g_nStrfsGood[client][ g_iStrfPos[client] ];
            }
            
#if defined DEBUG
            PrintToServer( INF_DEBUG_PRE..."Dot product: %06.2f", dot );
#endif
        }

        
        
        if ( ++g_nTickCount[client] >= g_nMaxTicks )
        {
            g_nTickCount[client] = 0;
            
            if ( ++g_iStrfPos[client] >= NUM_SECS )
            {
                g_iStrfPos[client] = 0;
                
                g_bUsedAll[client] = true;
            }
            
            g_nStrfsGood[client][ g_iStrfPos[client] ] = 0;
        }
    }
    
    flLastYaw[client] = angles[1];
    
    fLastFlags[client] = flags;
    
    return Plugin_Continue;
}

stock void ResetClient( int client )
{
    for ( int i = 0; i < NUM_SECS; i++ )
    {
        g_nStrfsGood[client][i] = 0;
    }
    
    g_iStrfPos[client] = 0;
    g_nTickCount[client] = 0;
    g_bUsedAll[client] = false;
}

stock float GetUnitVectorXY( const float vec[3], float target[3] )
{
    decl Float:temp[3];
    temp = vec;
    
    float len = SquareRoot( vec[0] * vec[0] + vec[1] * vec[1] );
    
    target[0] /= len;
    target[1] /= len;
    
    return len;
}

stock void RotateVectorXY( float vec[3], float ang_rad )
{
    float sin = Sine( ang_rad );
    float cos = Cosine( ang_rad );
    
    decl Float:temp[3];
    temp = vec;
    
    vec[0] = temp[0] * cos - temp[1] * sin;
    vec[1] = temp[0] * sin + temp[1] * cos;
}

stock float GetSync( int client )
{
    int num = ( g_bUsedAll[client] ) ? NUM_SECS : g_iStrfPos[client] + 1;
    
    
    int total = (g_nMaxTicks * num) - (g_nMaxTicks - g_nTickCount[client]);
    
    if ( total < 1 )
    {
        return 100.0;
    }
    
    int good = 0;
    
    
    for ( int i = 0; i < num; i++ )
    {
        good += g_nStrfsGood[client][i];
    }
    
    
    return (good / float( total )) * 100.0;
}

// NATIVES
public int Native_GetClientStrafeSync( Handle hPlugin, int nParms )
{
    return view_as<int>( GetSync( GetNativeCell( 1 ) ) );
}
