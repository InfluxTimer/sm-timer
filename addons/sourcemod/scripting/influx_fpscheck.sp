#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/fpscheck>

#include <msharedutil/ents>



//#define DEBUG



FpsVal_t g_iFpsVal[INF_MAXPLAYERS];
float g_flFps[INF_MAXPLAYERS];


ArrayList g_hCheck;


float g_flTickRate;


// FORWARDS
Handle g_hForward_OnRequestFpsChecks;


// CONVARS
ConVar g_ConVar_Type;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - FPS Check",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_FPSCHECK );
    
    
    // NATIVES
    CreateNative( "Influx_AddFpsCheck", Native_AddFpsCheck );
    CreateNative( "Influx_RemoveFpsCheck", Native_RemoveFpsCheck );
}

public void OnPluginStart()
{
    g_hCheck = new ArrayList( 1 );
    
    
    // FORWARDS
    g_hForward_OnRequestFpsChecks = CreateGlobalForward( "Influx_OnRequestFpsChecks", ET_Ignore );
    
    // CONVARS
    g_ConVar_Type = CreateConVar( "influx_fpscheck_type", "1", "How do we determine player's FPS in scroll modes? 0 = No limit. 1 = FPS can be more or equal to server's tickrate. 2 = FPS must be 300.", FCVAR_NOTIFY, true, 0.0, true, 2.0 );
    
    AutoExecConfig( true, "fpscheck", "influx" );
}

public void OnAllPluginsLoaded()
{
    //g_hCheck.Clear();
    
    // TODO: Remove me.
    Call_StartForward( g_hForward_OnRequestFpsChecks );
    Call_Finish();
}

public void OnMapStart()
{
    g_flTickRate = float( RoundFloat( 1.0 / GetTickInterval() ) );
}

public void OnClientPutInServer( int client )
{
    g_flFps[client] = 0.0;
    g_iFpsVal[client] = FPSVAL_NOTCACHED;
    

    if ( !IsFakeClient( client ) )
        CreateTimer( 2.0, T_QueryFps, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
}

stock void QueryClientFps( int client )
{
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Querying client %i fps_max!", client );
#endif
    QueryClientConVar( client, "fps_max", Q_Fps );
}

public void Q_Fps( QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue )
{
    if ( !IS_ENT_PLAYER( client ) ) return;
    
    if ( !IsClientInGame( client ) ) return;
    
    if ( IsFakeClient( client ) ) return;
    
    if ( result != ConVarQuery_Okay )
    {
        g_iFpsVal[client] = FPSVAL_NOTCACHED;
        
        CreateTimer( 1.0, T_QueryFps, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
        
        return;
    }
    
    
    float value = StringToFloat( cvarValue );
    
    g_iFpsVal[client] = FPSVAL_VALID;
    
    
    g_flFps[client] = value;
    
    
    if ( IsValidMode( Influx_GetClientMode( client ) ) && Influx_GetClientState( client ) == STATE_RUNNING )
    {
        PrintFpsStatus( client );
    }
}

stock void PrintFpsStatus( int client )
{
    decl String:szMsg[192];
    szMsg[0] = '\0';
    
    if ( !IsValidFps( client, szMsg, sizeof( szMsg ) ) && szMsg[0] != '\0' )
    {
        Influx_PrintToChat( _, client, szMsg );
    }
}

public Action T_QueryFps( Handle hTimer, int client )
{
    if ( (client = GetClientOfUserId( client )) > 0 && IsClientInGame( client ) )
    {
        QueryClientFps( client );
    }
}

public void Influx_OnClientModeChangePost( int client, int mode, int lastmode )
{
    if ( IsValidMode( mode ) )
    {
        PrintFpsStatus( client );
    }
}

public Action Influx_OnTimerStart( int client, int runid, char[] errormsg, int error_len )
{
    if ( !g_ConVar_Type.IntValue ) return Plugin_Continue;
    
    if ( !IsValidMode( Influx_GetClientMode( client ) ) ) return Plugin_Continue;
    
    
    return ( !IsValidFps( client, errormsg, error_len ) ) ? Plugin_Stop : Plugin_Continue;
}

public Action Influx_OnTimerFinish( int client, int runid, int mode, int style, float time, int flags, char[] errormsg, int error_len )
{
    if ( !g_ConVar_Type.IntValue ) return Plugin_Continue;
    
    if ( !IsValidMode( mode ) ) return Plugin_Continue;
    
    
    return ( !IsValidFps( client, errormsg, error_len ) ) ? Plugin_Stop : Plugin_Continue;
}

stock bool IsValidFps( int client, char[] msg, int msg_len )
{
    if ( g_iFpsVal[client] == FPSVAL_NOTCACHED )
    {
        strcopy( msg, msg_len, "Your fps_max value hasn't been received yet!" );
        return false;
    }
    else if ( g_iFpsVal[client] == FPSVAL_VALID )
    {
        switch ( g_ConVar_Type.IntValue )
        {
            case 1 : // More or equal to tickrate.
            {
                if ( g_flFps[client] != 0.0 && g_flFps[client] < g_flTickRate )
                {
                    FormatEx( msg, msg_len, "Your FPS must be equal to or greater than {MAINCLR1}%.0f{CHATCLR}!", g_flTickRate );
                    return false;
                }
            }
            case 2 : // Only 300.
            {
                if ( g_flFps[client] != 300.0 )
                {
                    strcopy( msg, msg_len, "Your FPS must be {MAINCLR1}300{CHATCLR}!" );
                    return false;
                }
            }
        }
        
        return true;
    }
    /*else if ( g_iFpsVal[client] == FPSVAL_INVALID )
    {
        FormatEx( msg, msg_len, "Your fps_max value of {MAINCLR1}%.0f{CHATCLR} is invalid!", g_flFps[client] );
        return false;
    }
    else // Cheated
    {
        strcopy( msg, msg_len, "Your FPS is cheated!" );
        return false;
    }*/
    
    return false;
}

stock bool IsValidMode( int mode )
{
    return ( FindCheckByMode( mode ) != -1 );
}

stock int FindCheckByMode( int id )
{
    int len = g_hCheck.Length;
    if ( len > 0 )
    {
        for ( int i = 0; i < len; i++ )
        {
            if ( g_hCheck.Get( i, 0 ) == id )
            {
                return i;
            }
        }
    }
    
    return -1;
}

// NATIVES
public int Native_AddFpsCheck( Handle hPlugin, int nParms )
{
    int mode = GetNativeCell( 1 );
    
    if ( FindCheckByMode( mode ) != -1 ) return 0;
    
    
    g_hCheck.Push( mode );
    
    return 1;
}

public int Native_RemoveFpsCheck( Handle hPlugin, int nParms )
{
    int mode = GetNativeCell( 1 );
    
    int index = FindCheckByMode( mode );
    
    if ( index == -1 ) return 0;
    
    
    g_hCheck.Erase( index );
    
    return 1;
}