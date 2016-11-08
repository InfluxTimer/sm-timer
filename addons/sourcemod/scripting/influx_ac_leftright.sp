#include <sourcemod>

#include <influx/core>
#include <influx/stocks_strf>


#undef REQUIRE_PLUGIN
#include <influx/practise>
#include <influx/pause>



#define NEXT_PRINT          3.0

#define RESET_TIME          0.2

#define MAX_CONT_STRFS      3



ConVar g_ConVar_Type;
ConVar g_ConVar_Req;


Strafe_t g_iLastStrafe[INF_MAXPLAYERS];
int g_nContStrfs[INF_MAXPLAYERS];
float g_flLastStrf[INF_MAXPLAYERS];
float g_flLastPrint[INF_MAXPLAYERS];


// LIBRARIES
bool g_bLib_Pause;
bool g_bLib_Practise;


bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Block +left/+right",
    description = "Blocks malicious use of +left/+right commands.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    g_bLate = late;
}

public void OnPluginStart()
{
    // CONVARS
    g_ConVar_Type = CreateConVar( "influx_ac_leftright", "1", "0 = Disable, 1 = Only disable spamming (strafe scripts), 2 = Never allow.", FCVAR_NOTIFY, true, 0.0, true, 2.0 );
    g_ConVar_Req = CreateConVar( "influx_ac_leftright_reqtimer", "0", "If true, allow while practising/paused/not running", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    AutoExecConfig( true, "ac_leftright", "influx" );
    
    
    // LIBRARIES
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
    g_bLib_Practise = LibraryExists( INFLUX_LIB_PRACTISE );
    
    
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
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = false;
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = false;
}

public void OnClientPutInServer( int client )
{
    g_iLastStrafe[client] = STRF_INVALID;
    g_nContStrfs[client] = 0;
    g_flLastStrf[client] = 0.0;
    g_flLastPrint[client] = 0.0;
}

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3] )
{
    if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
    
    if ( IsFakeClient( client ) ) return Plugin_Continue;
    
    if ( g_ConVar_Type.IntValue == 0 ) return Plugin_Continue;
    
    if ( g_ConVar_Req.BoolValue )
    {
        if (Influx_GetClientState( client ) == STATE_NONE
        ||  IS_PRAC( g_bLib_Practise, client )
        ||  IS_PAUSED( g_bLib_Pause, client ))
        {
            return Plugin_Continue;
        }
    }
    
    
    static float flLastValidYaw[INF_MAXPLAYERS];
    
    bool reset = false;
    
    
    // Holding both buttons down doesn't actually do anything.
    // Ignore it.
    int res = buttons & (IN_LEFT|IN_RIGHT);
    
    if ( res && res != (IN_LEFT|IN_RIGHT) )
    {
        if ( g_ConVar_Type.IntValue == 2 )
        {
            reset = true;
        }
        else
        {
            Strafe_t strf = ( res == IN_LEFT ) ? STRF_LEFT : STRF_RIGHT;
            
            if ( g_iLastStrafe[client] != STRF_INVALID && g_iLastStrafe[client] != strf )
            {
                ++g_nContStrfs[client];
            }
            
            
            g_iLastStrafe[client] = strf;
            
            g_flLastStrf[client] = GetEngineTime();
        }
    }
    else
    {
        flLastValidYaw[client] = angles[1];
    }
    
    
    if ( g_nContStrfs[client] > 0 )
    {
        if ( g_nContStrfs[client] >= MAX_CONT_STRFS )
        {
            reset = true;
        }
        
        
        if ( (GetEngineTime() - g_flLastStrf[client]) > RESET_TIME )
        {
            g_nContStrfs[client] = 0;
        }
    }
    
    
    if ( reset )
    {
        angles[1] = flLastValidYaw[client];
        
        if ( (GetEngineTime() - g_flLastPrint[client]) > NEXT_PRINT )
        {
            switch ( g_ConVar_Type.IntValue )
            {
                case 1 :
                {
                    Influx_PrintToChat( _, client, "Please don't spam {MAINCLR1}+left{CHATCLR}/{MAINCLR1}+right{CHATCLR}!" );
                }
                case 2 :
                {
                    Influx_PrintToChat( _, client, "Please don't use {MAINCLR1}+left{CHATCLR}/{MAINCLR1}+right{CHATCLR}!" );
                }
            }
            
            
            g_flLastPrint[client] = GetEngineTime();
        }
    }
    
    return Plugin_Continue;
}