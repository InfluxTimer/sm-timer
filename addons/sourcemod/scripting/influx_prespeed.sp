#include <sourcemod>

#include <influx/core>
#include <influx/prespeed>



#define INVALID_MAXSPD          -1.0
#define INVALID_MAXJUMPS        -2
#define INVALID_USETRUEVEL      -1
#define INVALID_DOCAP           -1


#define MAX_GROUND_SPD      280.0
#define MIN_GROUND_TIME     0.2 // Minimum amount of time a player needs to be on the ground before we reset jumps.


#define MIN_NC_PRESPEED         250.0 // Player has to go this slow after noclipping.
#define MIN_NC_PRESPEED_SQ      MIN_NC_PRESPEED * MIN_NC_PRESPEED


//#define DEBUG


enum
{
    PRESPEED_RUN_ID = 0,
    
    PRESPEED_MAX,
    PRESPEED_MAXJUMPS,
    
    PRESPEED_CAP,
    PRESPEED_USETRUEVEL,
    
    PRESPEED_SIZE
};

ArrayList g_hPre;



int g_nJumps[INF_MAXPLAYERS];
float g_flLastLand[INF_MAXPLAYERS];
bool g_bUsedNoclip[INF_MAXPLAYERS];



// CONVARS
ConVar g_ConVar_MaxJumps;
ConVar g_ConVar_Max;
ConVar g_ConVar_UseTrueVel;
ConVar g_ConVar_Cap;
ConVar g_ConVar_Noclip;


// FORWARDS
Handle g_hForward_OnLimitClientPrespeed;


bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Prespeed",
    description = "Handles prespeed.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    g_bLate = late;
    
    
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_PRESPEED );
}

public void OnPluginStart()
{
    g_hPre = new ArrayList( PRESPEED_SIZE );
    
    
    // FORWARDS
    g_hForward_OnLimitClientPrespeed = CreateGlobalForward( "Influx_OnLimitClientPrespeed", ET_Hook, Param_Cell, Param_Cell );
    
    
    // CONVARS
    g_ConVar_MaxJumps = CreateConVar( "influx_prespeed_maxjumps", "-1", "Maximum number of jumps a player can do before starting a run? -1 = disable", FCVAR_NOTIFY, true, -1.0 );
    g_ConVar_Max = CreateConVar( "influx_prespeed_max", "300", "Default max prespeed. 0 = disable", FCVAR_NOTIFY, true, 0.0 );
    g_ConVar_UseTrueVel = CreateConVar( "influx_prespeed_usetruevel", "0", "Use truevel when checking player's speed.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_Cap = CreateConVar( "influx_prespeed_cap", "1", "If true, cap player's speed to max prespeed. Otherwise teleport.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_Noclip = CreateConVar( "influx_prespeed_noclip", "1", "If true, don't allow players to prespeed with noclip.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    AutoExecConfig( true, "prespeed", "influx" );
    
    
    // EVENTS
    HookEvent( "player_jump", E_PlayerJump );
    
    
    if ( g_bLate )
    {
        Influx_OnPreRunLoad();
        
        ArrayList runs = Influx_GetRunsArray();
        int len = runs.Length;
        
        for ( int i = 0; i < len; i++ )
        {
            Influx_OnRunCreated( runs.Get( i, RUN_ID ) );
        }
    }
}

public void OnClientPutInServer( int client )
{
    g_nJumps[client] = 0;
    g_flLastLand[client] = 0.0;
    
    if ( !IsFakeClient( client ) )
    {
        Inf_SDKHook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client );
    }
}

public void Influx_OnPreRunLoad()
{
    g_hPre.Clear();
}

public void Influx_OnRunCreated( int runid )
{
    if ( FindPreById( runid ) != -1 ) return;
    
    
    decl data[PRESPEED_SIZE];
    
    data[PRESPEED_RUN_ID] = runid;
    
    data[PRESPEED_MAX] = view_as<int>( INVALID_MAXSPD );
    data[PRESPEED_MAXJUMPS] = INVALID_MAXJUMPS;
    data[PRESPEED_USETRUEVEL] = INVALID_USETRUEVEL;
    data[PRESPEED_CAP] = INVALID_DOCAP;
    
    g_hPre.PushArray( data );
}

public void Influx_OnRunDeleted( int runid )
{
    int index = FindPreById( runid );
    if ( index != -1 )
    {
        g_hPre.Erase( index );
    }
}

public void Influx_OnRunLoad( int runid, KeyValues kv )
{
    if ( FindPreById( runid ) != -1 ) return;
    
    
    decl data[PRESPEED_SIZE];
    
    data[PRESPEED_RUN_ID] = runid;
    
    data[PRESPEED_MAX] = view_as<int>( kv.GetFloat( "prespeed_max", INVALID_MAXSPD ) );
    data[PRESPEED_MAXJUMPS] = kv.GetNum( "prespeed_maxjumps", INVALID_MAXJUMPS );
    data[PRESPEED_USETRUEVEL] = kv.GetNum( "prespeed_usetruevel", INVALID_USETRUEVEL );
    data[PRESPEED_CAP] = kv.GetNum( "prespeed_cap", INVALID_DOCAP );
    
    g_hPre.PushArray( data );
}

public void Influx_OnRunSave( int runid, KeyValues kv )
{
    int index = FindPreById( runid );
    if ( index == -1 ) return;
    
    
    decl data[PRESPEED_SIZE];
    g_hPre.GetArray( index, data );
    
    float maxprespd = view_as<float>( data[PRESPEED_MAX] );
    int maxjumps = data[PRESPEED_MAXJUMPS];
    int truevel = data[PRESPEED_USETRUEVEL];
    int cap = data[PRESPEED_CAP];
    
    if ( maxprespd != INVALID_MAXSPD && maxprespd != g_ConVar_Max.FloatValue )
    {
        kv.SetFloat( "prespeed_max", maxprespd );
    }
    
    if ( maxjumps != INVALID_MAXJUMPS && maxjumps != g_ConVar_MaxJumps.IntValue )
    {
        kv.SetNum( "prespeed_maxjumps", maxjumps );
    }
    
    if ( truevel != INVALID_USETRUEVEL && truevel != g_ConVar_UseTrueVel.IntValue )
    {
        kv.SetNum( "prespeed_usetruevel", truevel ? 1 : 0 );
    }
    
    if ( cap != INVALID_DOCAP && cap != g_ConVar_Cap.IntValue )
    {
        kv.SetNum( "prespeed_cap", cap ? 1 : 0 );
    }
}

public Action Influx_OnTimerStart( int client, int runid, char[] errormsg, int error_len )
{
    int index = FindPreById( runid );
    if ( index == -1 ) return Plugin_Continue;
    
    
    if ( g_ConVar_Noclip.BoolValue && g_bUsedNoclip[client] )
    {
        FormatEx( errormsg, error_len, "You cannot prespeed with noclip!" );
        return Plugin_Handled;
    }
    
    
    // Check jump count.
    int maxjumps = g_hPre.Get( index, PRESPEED_MAXJUMPS );
    if ( maxjumps == -2 ) maxjumps = g_ConVar_MaxJumps.IntValue;
    
    
    if ( maxjumps >= 0 )
    {
        if ( g_nJumps[client] > maxjumps )
        {
            if ( SendLimitForward( client, g_bUsedNoclip[client] ) )
            {
                if ( maxjumps )
                {
                    FormatEx( errormsg, error_len, "You cannot jump more than {MAINCLR1}%i{CHATCLR} time(s) at the start!", maxjumps );
                }
                else
                {
                    FormatEx( errormsg, error_len, "You cannot jump at all at the start!" );
                }
                
                
                return Plugin_Handled;
            }
        }
    }
    
    
    // Check prespeed.
    float maxprespd = g_hPre.Get( index, PRESPEED_MAX );
    if ( maxprespd == -1.0 ) maxprespd = g_ConVar_Max.FloatValue;
    
    
    if ( maxprespd > 0.0 )
    {
        float vel[3];
        GetEntityVelocity( client, vel );
        
        bool bBadSpd = false;
        
        float spd = SquareRoot( vel[0] * vel[0] + vel[1] * vel[1] );
        float truespd = SquareRoot( vel[0] * vel[0] + vel[1] * vel[1] + vel[2] * vel[2] );
        
        
        int usetruevel = g_hPre.Get( index, PRESPEED_USETRUEVEL );
        if ( usetruevel == -1 ) usetruevel = g_ConVar_UseTrueVel.IntValue;
        
        if ( usetruevel )
        {
            bBadSpd = ( truespd > maxprespd );
        }
        else
        {
            bBadSpd = ( spd > maxprespd );
        }
        
        if ( bBadSpd )
        {
#if defined DEBUG
            PrintToServer( INF_DEBUG_PRE..."Bad prespeed (%i) (%.1f | %.1f)", client, spd, truespd );
#endif
            
            int capstyle = g_hPre.Get( index, PRESPEED_CAP );
            if ( capstyle == -1 ) capstyle = g_ConVar_Cap.IntValue;
            
            
            if ( SendLimitForward( client, g_bUsedNoclip[client] ) )
            {
                if ( capstyle )
                {
                    float m = truespd / maxprespd;
                    
                    vel[0] /= m;
                    vel[1] /= m;
                    vel[2] /= m;
                    
                    TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, vel );
                }
                else
                {
                    FormatEx( errormsg, error_len, "Your prespeed cannot exceed {MAINCLR1}%.0f{CHATCLR}!", maxprespd );
                    return Plugin_Handled;
                }
            }
        }
    }
    
    return Plugin_Continue;
}

public Action OnPlayerRunCmd( int client )
{
    if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
    
    
    static int fLastFlags[INF_MAXPLAYERS];
    
    
    int flags = GetEntityFlags( client );
    
    
    if ( !(fLastFlags[client] & FL_ONGROUND) && flags & FL_ONGROUND )
    {
        g_flLastLand[client] = GetEngineTime();
    }
    
    
    if ( g_nJumps[client] > 0 )
    {
        if (flags & FL_ONGROUND
        &&  GetEntitySpeed( client ) < MAX_GROUND_SPD
        &&  (GetEngineTime() - g_flLastLand[client]) > MIN_GROUND_TIME )
        {
#if defined DEBUG
            PrintToServer( INF_DEBUG_PRE..."Resetting player's %i jumps. (%i)", client, g_nJumps[client] );
#endif
            g_nJumps[client] = 0;
        }
    }
    
    
    fLastFlags[client] = flags;
    
    return Plugin_Continue;
}

public void E_PlayerJump( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( GetEventInt( event, "userid" ) );
    if ( !client ) return;
    
    if ( !IsPlayerAlive( client ) ) return;
    
    
    ++g_nJumps[client];
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Player %i has jumped consecutively %i times.", client, g_nJumps[client] );
#endif
}

public void E_PreThinkPost_Client( int client )
{
    if ( GetEntityMoveType( client ) == MOVETYPE_NOCLIP )
    {
        g_bUsedNoclip[client] = true;
    }
    else if ( g_bUsedNoclip[client] && GetEntityTrueSpeedSquared( client ) < MIN_NC_PRESPEED_SQ )
    {
        g_bUsedNoclip[client] = false;
    }
}

stock int FindPreById( int id )
{
    int len = g_hPre.Length;
    if ( len > 0 )
    {
        for ( int i = 0; i < len; i++ )
        {
            if ( g_hPre.Get( i, PRESPEED_RUN_ID ) == id ) return i;
        }
    }
    
    return -1;
}

stock bool SendLimitForward( int client, bool bUsedNoclip )
{
    Action res = Plugin_Continue;
    
    Call_StartForward( g_hForward_OnLimitClientPrespeed );
    Call_PushCell( client );
    Call_PushCell( bUsedNoclip );
    Call_Finish( res );
    
    
    return ( res == Plugin_Continue ) ? true : false
}