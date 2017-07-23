#include <sourcemod>
#include <sdkhooks>

#include <influx/core>
#include <influx/ac_log>


#include <msharedutil/ents>


//#define DEBUG
//#define DEBUG_DIF


#define TIME_TO_COUNT       2.0
#define MIN_TICKS_IN_AIR    10
#define MIN_GAINS_FOR_INC   60 // Our gains must be at least this much to log gain increases.


float g_flLastYaw[INF_MAXPLAYERS];
float g_vecLastVel[INF_MAXPLAYERS][3];
int g_fLastFlags[INF_MAXPLAYERS];


float g_flTotal[INF_MAXPLAYERS];
float g_flTotalDif[INF_MAXPLAYERS];
int g_nTicks[INF_MAXPLAYERS];

//float g_flAvgGains[INF_MAXPLAYERS];
float g_flLastGains[INF_MAXPLAYERS];
int g_nGainTimesForLog[INF_MAXPLAYERS];
int g_nGainTimesForPunish[INF_MAXPLAYERS];


// CONVARS
ConVar g_ConVar_NumJumps;
ConVar g_ConVar_MaxGainsForPunish;
ConVar g_ConVar_MaxGainsForLog;
ConVar g_ConVar_MaxGainsIncForLog;
//ConVar g_ConVar_PunishType;
//ConVar g_ConVar_PunishAmount;


int g_nMaxTicks;


bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Anti-Cheat | Gains",
    description = "Monitors player's gains.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    g_bLate = late;
}

public void OnPluginStart()
{
    g_nMaxTicks = RoundFloat( TIME_TO_COUNT * (1.0 / GetTickInterval()) );
    
    
    // CONVARS
    g_ConVar_NumJumps = CreateConVar( "influx_ac_gains_jumpnum", "3", "Amount of jumps to weigh when logging/punishing.", FCVAR_NOTIFY, true, 2.0 );
    g_ConVar_MaxGainsForPunish = CreateConVar( "influx_ac_gains_maxgainspunish", "93", "If player has this much consistent gain then punish them. 0 = disable", FCVAR_NOTIFY, true, 0.0, true, 100.0 );
    g_ConVar_MaxGainsForLog = CreateConVar( "influx_ac_gains_maxgainslog", "90", "If player has this much consistent gain then log their action. 0 = disable", FCVAR_NOTIFY, true, 0.0, true, 100.0 );
    g_ConVar_MaxGainsIncForLog = CreateConVar( "influx_ac_gains_maxgainsinclog", "28", "If player's gains increases this much then log. 0 = disable", FCVAR_NOTIFY, true, 0.0, true, 100.0 );
    //g_ConVar_PunishType = CreateConVar( "influx_ac_gains_punishtype", "1", "0 = Disabled, 1 = Use log-module's punishment", FCVAR_NOTIFY, true, 0.0, true, 1.0 ); // , 2 = Kick/ban
    //g_ConVar_PunishAmount = CreateConVar( "influx_ac_gains_punishtime", "-1", "-1 = Kick, 0 = Perma, >0 = Ban for this long (in minutes)", FCVAR_NOTIFY, true, -1.0 );
    
    
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

public void OnClientPutInServer( int client )
{
    if ( !IsFakeClient( client ) )
    {
        Inf_SDKHook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
    }
    
    ResetClient( client );
    
    //g_flAvgGains[client] = 0.0;
    
    g_flLastGains[client] = 0.0;
    
    g_nGainTimesForLog[client] = 0;
    g_nGainTimesForPunish[client] = 0;
}

stock void ResetClient( int client )
{
    g_flTotal[client] = 0.0;
    g_flTotalDif[client] = 0.0;
    
    g_nTicks[client] = 0;
}

public void E_PostThinkPost_Client( int client )
{
#define AIRCAP      30.0

    int flags = GetEntityFlags( client );
    
    decl Float:ang[3];
    GetClientEyeAngles( client, ang );
    
    decl Float:curvel[3];
    GetEntityAbsVelocity( client, curvel );
    curvel[2] = 0.0;
    
    float curspd = GetVectorLength( curvel, false );
    
    
    float lastspd = GetVectorLength( g_vecLastVel[client], false );
    
    if ( !(flags & FL_ONGROUND) && curspd > lastspd && lastspd != 0.0 && g_flLastYaw[client] != ang[1] )
    {
        float bestlastdelta = RadToDeg( ArcTangent( AIRCAP / lastspd ) );
        
        
        float curmoveyaw = ArcTangent2( curvel[1], curvel[0] );
        float lastmoveyaw = ArcTangent2( g_vecLastVel[client][1], g_vecLastVel[client][0] );
        
        float delta = FloatAbs( NormalizeAngle( RadToDeg( curmoveyaw - lastmoveyaw ) ) );
        
        float dif = FloatAbs( bestlastdelta - delta );
        
#if defined DEBUG_DIF
        PrintToServer( "Dif: %.1f", dif );
#endif
        
        g_flTotal[client] += bestlastdelta;
        g_flTotalDif[client] += dif;
        
        if ( ++g_nTicks[client] > g_nMaxTicks )
        {
            CalcGains( client );
        }
    }
    
    if ( flags & FL_ONGROUND && !(g_fLastFlags[client] & FL_ONGROUND) )
    {
        CalcGains( client );
    }
    
    
    g_fLastFlags[client] = flags;
    g_flLastYaw[client] = ang[1];
    g_vecLastVel[client] = curvel;
}

stock void CalcGains( int client )
{
    if ( g_nTicks[client] < MIN_TICKS_IN_AIR ) return;
    
    if ( g_flTotal[client] == 0.0 ) return;
    
    
    float g = ( (g_flTotal[client] - g_flTotalDif[client]) / g_flTotal[client] ) * 100.0;
    
    
    //float num = ( g_flAvgGains[client] == 0.0 ) ? 1.0 : 2.0;
    
    
#if defined DEBUG
    PrintToServer( "Perc: %.1f | Avg: %.1f", g, (g_flLastGains[client] + g) / 2.0 );
#endif
    
    
    if ( g_ConVar_MaxGainsIncForLog.FloatValue != 0.0 && g_flLastGains[client] != 0.0 && g_flLastGains[client] >= MIN_GAINS_FOR_INC )
    {
        float gaininc = g - g_flLastGains[client];
        
        if ( gaininc >= g_ConVar_MaxGainsIncForLog.FloatValue )
        {
            Influx_LogCheat( client, "Gains increased more than %.0f percent! (Last: %.0f | New: %.0f)",
                g_ConVar_MaxGainsIncForLog.FloatValue,
                g_flLastGains[client],
                g );
        }
    }
    
    
    bool bLogged = false;
    
    if ( g_ConVar_MaxGainsForPunish.FloatValue != 0.0 && g >= g_ConVar_MaxGainsForPunish.FloatValue )
    {
        if ( ++g_nGainTimesForPunish[client] >= g_ConVar_NumJumps.IntValue )
        {
            bLogged = Influx_PunishCheat( client, _, "Your gains we're too damn high!", "Gains exceeded %.0f percent! (%.0f percent)",
                g_ConVar_MaxGainsForPunish.FloatValue,
                g );
            
            g_nGainTimesForPunish[client] = 0;
        }
    }
    else
    {
        if ( g_nGainTimesForPunish[client] > 0 )
            --g_nGainTimesForPunish[client];
    }
    
    // Don't double log...
    if ( !bLogged && g_ConVar_MaxGainsForLog.FloatValue != 0.0 && g >= g_ConVar_MaxGainsForLog.FloatValue )
    {
        if ( ++g_nGainTimesForLog[client] >= g_ConVar_NumJumps.IntValue )
        {
            Influx_LogCheat( client, "Gains exceeded %.0f percent! (%.0f percent)",
                g_ConVar_MaxGainsForLog.FloatValue,
                g );
            
            g_nGainTimesForLog[client] = 0;
        }
    }
    else
    {
        if ( g_nGainTimesForLog[client] > 0 )
            --g_nGainTimesForLog[client];
    }
    
    
    g_flLastGains[client] = g;
    
    ResetClient( client );
}

stock float NormalizeAngle( float ang )
{
    if ( ang > 180.0 )
    {
        ang -= 360.0;
    }
    else if ( ang < -180.0 )
    {
        ang += 360.0;
    }
    
    return ang;
}
