#include <sourcemod>


// If you want to use this somewhere else, comment this out.
#define REQUIRE_INFLUX



#if !defined REQUIRE_INFLUX
#undef REQUIRE_PLUGIN
#endif
#include <influx/core>

#include <influx/stocks_strf>

#include <msharedutil/ents>


//#define DEBUG


#define INF_PRIVCOM_SHOWKEYS    "sm_inf_showkeys"


#define MAX_SAMPLES             10


bool g_bShowKeys[INF_MAXPLAYERS];

int g_fButtons[INF_MAXPLAYERS];
float g_vecLastVel[INF_MAXPLAYERS][3];
float g_vecVel[INF_MAXPLAYERS][3];
float g_flYaw[INF_MAXPLAYERS];
float g_flLastYaw[INF_MAXPLAYERS];

int g_nLeftStrfDif[INF_MAXPLAYERS];
int g_nLeftStrfDif_Display[INF_MAXPLAYERS];
int g_nRightStrfDif[INF_MAXPLAYERS];
int g_nRightStrfDif_Display[INF_MAXPLAYERS]

int g_nLeftKeyDif[INF_MAXPLAYERS];
int g_nLeftKeyDif_Display[INF_MAXPLAYERS];
int g_nRightKeyDif[INF_MAXPLAYERS];
int g_nRightKeyDif_Display[INF_MAXPLAYERS];

int g_nPauseStrf[INF_MAXPLAYERS];
int g_nPauseStrf_Display[INF_MAXPLAYERS];
int g_nPauseKey[INF_MAXPLAYERS];
int g_nPauseKey_Display[INF_MAXPLAYERS];

float g_flLeftStrf_Time[INF_MAXPLAYERS];
float g_flRightStrf_Time[INF_MAXPLAYERS];
float g_flLeftKey_Time[INF_MAXPLAYERS];
float g_flRightKey_Time[INF_MAXPLAYERS];

float g_flPauseStrf_Time[INF_MAXPLAYERS];
float g_flPauseKey_Time[INF_MAXPLAYERS];


ConVar g_ConVar_DrawInterval;

int g_nNextDraw;

bool g_bEnabled;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Advanced Show Keys",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CONVARS
    g_ConVar_DrawInterval = CreateConVar( "influx_advshowkeys_drawinterval", "0", "Draw interval in seconds for keys. Should be extremely low. Don't change unless you know what you're doing. 0 = Every tick", FCVAR_NOTIFY, true, 0.0, true, 5.0 );
    
    
    // PRIVILEGE CMDS
    RegAdminCmd( INF_PRIVCOM_SHOWKEYS, Cmd_Empty, 0 );
    
    
    // CMDS
    RegConsoleCmd( "sm_showkeys", Cmd_ShowKeys );
    RegConsoleCmd( "sm_keys", Cmd_ShowKeys );
}

public void OnMapStart()
{
    g_nNextDraw = 0;
}

public Action Cmd_Empty( int client, int args ) { return Plugin_Handled; }

public Action Cmd_ShowKeys( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserShowKeys( client ) ) return Plugin_Handled;
    
    
    g_bShowKeys[client] = !g_bShowKeys[client];
    
    if ( g_bShowKeys[client] )
    {
        g_bEnabled = true;
    }
    else
    {
        CheckEnabled();
    }
    
    
    return Plugin_Handled;
}

public void OnClientPutInServer( int client )
{
    g_nLeftStrfDif[client] = 0;
    g_nRightStrfDif[client] = 0;
    g_nLeftStrfDif_Display[client] = 0;
    g_nRightStrfDif_Display[client] = 0;
    
    g_nLeftKeyDif[client] = 0;
    g_nRightKeyDif[client] = 0;
    g_nLeftKeyDif_Display[client] = 0;
    g_nRightKeyDif_Display[client] = 0;
    
    g_nPauseStrf[client] = 0;
    g_nPauseStrf_Display[client] = 0;
    
    g_nPauseKey[client] = 0;
    g_nPauseKey_Display[client] = 0;
    
    g_flLeftStrf_Time[client] = 0.0;
    g_flRightStrf_Time[client] = 0.0;
    
    g_flLeftKey_Time[client] = 0.0;
    g_flRightKey_Time[client] = 0.0;
    
    g_flPauseStrf_Time[client] = 0.0;
    g_flPauseKey_Time[client] = 0.0;
}

public void OnClientDisconnect( int client )
{
    if ( g_bShowKeys[client] )
    {
        g_bShowKeys[client] = false;
        
        CheckEnabled();
    }
}

public void OnGameFrame()
{
    if ( !g_bEnabled ) return;
    
    
    int tick = GetGameTickCount();
    
    if ( tick < g_nNextDraw ) return;
    
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) ) continue;
        
        if ( IsFakeClient( i ) ) continue;
        
        if ( !g_bShowKeys[i] ) continue;
        
        
        ShowKeys( i, GetClientTarget( i ) );
    }
    
    g_nNextDraw = tick + RoundFloat( g_ConVar_DrawInterval.FloatValue / GetTickInterval() );
}

stock int GetClientTarget( int client )
{
    if ( !IsPlayerAlive( client ) )
    {
        int target = GetClientObserverTarget( client );
        
        return (
            IS_ENT_PLAYER( target )
        &&  IsClientInGame( target )
        &&  IsPlayerAlive( target )
        &&  GetClientObserverMode( client ) != OBS_MODE_ROAMING ) ? target : 0;
    }
    else
    {
        return client;
    }
}

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3] )
{
    if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
    
    
    Strafe_t laststrf = GetStrafe( g_flYaw[client], g_flLastYaw[client] );
    
    
    g_fButtons[client] = buttons;
    g_vecLastVel[client] = g_vecVel[client];
    g_vecVel[client] = vel;
    g_flLastYaw[client] = g_flYaw[client];
    g_flYaw[client] = angles[1];
    
    
    float time = GetEngineTime();
    
    Strafe_t strf = GetStrafe( g_flYaw[client], g_flLastYaw[client] );
    
    
    if ( strf == STRF_LEFT )
    {
        if ( g_vecVel[client][1] >= 0.0 )
        {
            if ( g_nLeftStrfDif[client] < MAX_SAMPLES )
                ++g_nLeftStrfDif[client];
        }
        else if ( g_vecLastVel[client][1] >= 0.0 )
        {
            g_nLeftStrfDif_Display[client] = g_nLeftStrfDif[client];
            g_nLeftStrfDif[client] = 0;
            
            g_flLeftStrf_Time[client] = time;
        }
    }
    else if ( strf == STRF_RIGHT )
    {
        if ( g_vecVel[client][1] <= 0.0 )
        {
            if ( g_nRightStrfDif[client] < MAX_SAMPLES )
                ++g_nRightStrfDif[client];
        }
        else if ( g_vecLastVel[client][1] <= 0.0 )
        {
            g_nRightStrfDif_Display[client] = g_nRightStrfDif[client];
            g_nRightStrfDif[client] = 0;
            
            g_flRightStrf_Time[client] = time;
        }
    }
    
    if ( g_vecVel[client][1] < 0.0 )
    {
        if ( strf != STRF_LEFT )
        {
            if ( g_nLeftKeyDif[client] < MAX_SAMPLES )
                ++g_nLeftKeyDif[client];
        }
        else if ( laststrf != STRF_LEFT )
        {
            g_nLeftKeyDif_Display[client] = g_nLeftKeyDif[client];
            g_nLeftKeyDif[client] = 0;
            
            g_flLeftKey_Time[client] = time;
        }
    }
    else if ( g_vecVel[client][1] > 0.0 )
    {
        if ( strf != STRF_RIGHT )
        {
            if ( g_nRightKeyDif[client] < MAX_SAMPLES )
                ++g_nRightKeyDif[client];
        }
        else if ( laststrf != STRF_RIGHT )
        {
            g_nRightKeyDif_Display[client] = g_nRightKeyDif[client];
            g_nRightKeyDif[client] = 0;
            
            g_flRightKey_Time[client] = time;
        }
    }
    
    
    if ( strf == STRF_INVALID )
    {
        if ( g_nPauseStrf[client] < MAX_SAMPLES )
            ++g_nPauseStrf[client];
    }
    else if ( laststrf != strf )
    {
        g_nPauseStrf_Display[client] = g_nPauseStrf[client];
        g_nPauseStrf[client] = 0;
        
        g_flPauseStrf_Time[client] = time;
    }
    
    
    if ( g_vecVel[client][1] == 0.0 )
    {
        if ( g_nPauseKey[client] < MAX_SAMPLES )
            ++g_nPauseKey[client];
    }
    else if ( g_vecLastVel[client][1] != g_vecVel[client][1] )
    {
        g_nPauseKey_Display[client] = g_nPauseKey[client];
        g_nPauseKey[client] = 0;
        
        g_flPauseKey_Time[client] = time;
    }
    
    return Plugin_Continue;
}

stock void ShowKeys( int client, int target )
{
    float time = GetEngineTime();
    
    
    Strafe_t strf = GetStrafe( g_flYaw[target], g_flLastYaw[target] );
    
#define BOTH_SIDE       (IN_MOVELEFT|IN_MOVERIGHT)
#define BOTH_FWD        (IN_FORWARD|IN_BACK)
    
    bool both_side = ( (g_fButtons[target] & BOTH_SIDE) == BOTH_SIDE ) ? true : false;
    bool both_fwd = ( (g_fButtons[target] & BOTH_FWD) == BOTH_FWD ) ? true : false;
    
    char szLeftStrf[4];
    char szRightStrf[4];
    char szLeftKey[4];
    char szRightKey[4];
    
    char szPauseStrf[4];
    char szPauseKey[4];
    
    GetTickDisplay( szLeftStrf, sizeof( szLeftStrf ), g_nLeftStrfDif_Display[target], time - g_flLeftStrf_Time[target] );
    GetTickDisplay( szRightStrf, sizeof( szRightStrf ), g_nRightStrfDif_Display[target], time - g_flRightStrf_Time[target] );
    GetTickDisplay( szLeftKey, sizeof( szLeftKey ), g_nLeftKeyDif_Display[target], time - g_flLeftKey_Time[target] );
    GetTickDisplay( szRightKey, sizeof( szRightKey ), g_nRightKeyDif_Display[target], time - g_flRightKey_Time[target] );
    
    GetTickDisplay( szPauseStrf, sizeof( szPauseStrf ), g_nPauseStrf_Display[target], time - g_flPauseStrf_Time[target] );
    GetTickDisplay( szPauseKey, sizeof( szPauseKey ), g_nPauseKey_Display[target], time - g_flPauseKey_Time[target] );
    
    PrintCenterText( client, "    %s\n%s%s%s%s%s\n%s%s%s%s%s\n    %s\n %s",
        szPauseStrf,
        szLeftStrf,
        strf == STRF_LEFT ? "<" : "  ",
        ( g_vecVel[target][0] > 0.0 || both_fwd ) ? "W" : "_",
        strf == STRF_RIGHT ? ">" : "  ",
        szRightStrf,
        szLeftKey,
        ( g_vecVel[target][1] < 0.0 || both_side ) ? "A" : "_",
        ( g_vecVel[target][0] < 0.0 || both_fwd ) ? "S" : "_",
        ( g_vecVel[target][1] > 0.0 || both_side ) ? "D" : "_",
        szRightKey,
        szPauseKey,
        ( g_fButtons[target] & IN_JUMP ) ? "JUMP" : "____" );
}

stock void GetTickDisplay( char[] out, int len, int ticks, float time )
{
    if ( ticks >= MAX_SAMPLES || ticks < 0 || time > 10.0 )
    {
        strcopy( out, len, "~" );
    }
    else
    {
        FormatEx( out, len, "%i", ticks );
    }
}

stock void CheckEnabled()
{
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) ) continue;
        
        if ( IsFakeClient( i ) ) continue;
        
        
        if ( g_bShowKeys[i] ) return;
    }
    
    g_bEnabled = false;
}

stock bool CanUserShowKeys( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_SHOWKEYS, 0 );
}