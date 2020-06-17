#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/stocks_core>

#include <msharedutil/ents>


#undef REQUIRE_PLUGIN
#include <influx/zones_freestyle>
#include <influx/fpscheck>


//#define DEBUG_THINK


float g_flAirAccelerate = 100.0;


ConVar g_ConVar_AirAccelerate;
ConVar g_ConVar_EnableBunnyhopping;

ConVar g_ConVar_VelCap_AirAccelerate;
ConVar g_ConVar_VelCap;


bool g_bLib_Zones_Fs;
bool g_bLib_FpsCheck;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Mode - VelCap",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    if ( (g_ConVar_AirAccelerate = FindConVar( "sv_airaccelerate" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_airaccelerate!" );
    }
    
    
    if ( (g_ConVar_EnableBunnyhopping = FindConVar( "sv_enablebunnyhopping" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_enablebunnyhopping!" );
    }
    
    
    g_ConVar_VelCap_AirAccelerate = CreateConVar( "influx_velcap_airaccelerate", "100", "", FCVAR_NOTIFY );
    g_ConVar_VelCap_AirAccelerate.AddChangeHook( E_CvarChange_VelCap_AA );
    
    g_ConVar_VelCap = CreateConVar( "influx_velcap", "400", "Maximum ground speed.", FCVAR_NOTIFY );
    
    AutoExecConfig( true, "mode_velcap", "influx" );
    
    
    RegConsoleCmd( "sm_vel", Cmd_Mode_VelCap, INF_NAME..." - Change your mode to velcap." );
    RegConsoleCmd( "sm_velcap", Cmd_Mode_VelCap, "" );
    RegConsoleCmd( "sm_v", Cmd_Mode_VelCap, "" );
    
    
    g_bLib_Zones_Fs = LibraryExists( INFLUX_LIB_ZONES_FS );
    g_bLib_FpsCheck = LibraryExists( INFLUX_LIB_FPSCHECK );
}

public void OnAllPluginsLoaded()
{
    AddMode();
    
    if ( g_bLib_FpsCheck )
    {
        Influx_AddFpsCheck( MODE_VELCAP );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveMode( MODE_VELCAP );
    
    if ( g_bLib_FpsCheck )
    {
        Influx_RemoveFpsCheck( MODE_VELCAP );
    }
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_ZONES_FS ) ) g_bLib_Zones_Fs = true;
    if ( StrEqual( lib, INFLUX_LIB_FPSCHECK ) ) g_bLib_FpsCheck = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_ZONES_FS ) ) g_bLib_Zones_Fs = false;
    if ( StrEqual( lib, INFLUX_LIB_FPSCHECK ) ) g_bLib_FpsCheck = false;
}

public void Influx_OnRequestModes()
{
    AddMode();
}

stock void AddMode()
{
    if ( !Influx_AddMode( MODE_VELCAP, "VelCap", "VelCap", "velcap" ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add mode! (%i)", MODE_VELCAP );
    }
}

public void Influx_OnRequestFpsChecks()
{
    Influx_AddFpsCheck( MODE_VELCAP );
}

public void OnClientDisconnect( int client )
{
    UnhookThinks( client );
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "velcap", false )
    ||  StrEqual( szArg, "400vel", false ) )
    {
        value = MODE_VELCAP;
        type = SEARCH_MODE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Influx_OnClientModeChange( int client, int mode, int lastmode )
{
    if ( mode == MODE_VELCAP )
    {
        UnhookThinks( client );
        
        
        if ( !Inf_SDKHook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client ) )
        {
            return Plugin_Handled;
        }
        
        Inf_SendConVarValueFloat( client, g_ConVar_AirAccelerate, g_ConVar_VelCap_AirAccelerate.FloatValue );
        Inf_SendConVarValueBool( client, g_ConVar_EnableBunnyhopping, true );
    }
    else if ( lastmode == MODE_VELCAP )
    {
        UnhookThinks( client );
    }
    
    return Plugin_Continue;
}

stock void UnhookThinks( int client )
{
    SDKUnhook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client );
}

public void E_CvarChange_VelCap_AA( ConVar convar, const char[] oldval, const char[] newval )
{
    g_flAirAccelerate = convar.FloatValue;
}

public void E_PreThinkPost_Client( int client )
{
#if defined DEBUG_THINK
    PrintToServer( INF_DEBUG_PRE..."PreThinkPost - VelCap (aa: %.0f)", g_flAirAccelerate );
#endif
    
    if ( Influx_GetClientMode( client ) != MODE_VELCAP )
    {
        RequestFrame( UnhookThinksCb, GetClientUserId( client ) );
        return;
    }


    g_ConVar_AirAccelerate.FloatValue = g_flAirAccelerate;
    g_ConVar_EnableBunnyhopping.BoolValue = true;
}

public Action OnPlayerRunCmd( int client )
{
    if (IsPlayerAlive( client )
    &&  Influx_GetClientMode( client ) == MODE_VELCAP
    &&  GetEntityFlags( client ) & FL_ONGROUND
    &&  GetEntityMoveType( client ) == MOVETYPE_WALK
    // Freestylin' makes you go fast!
    &&  (!g_bLib_Zones_Fs || !Influx_CanClientModeFreestyle( client )) )
    {
        float velcap = g_ConVar_VelCap.FloatValue;
        
        decl Float:spd;
        decl Float:vel[3];
        
        
        GetEntityVelocity( client, vel );
        
        spd = vel[0] * vel[0] + vel[1] * vel[1];// + vel[2] * vel[2];
        
        if ( spd > (velcap * velcap) )
        {
            spd = SquareRoot( spd ) / velcap;
            
            vel[0] /= spd;
            vel[1] /= spd;
            
            TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, vel );
        }
    }
    
    return Plugin_Continue;
}

public void UnhookThinksCb( int userid ) // Can't unhook inside hook
{
    int client = GetClientOfUserId( userid );
    if ( client <= 0 || !IsClientInGame( client ) )
        return;


    UnhookThinks( client );
}

public Action Cmd_Mode_VelCap( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientMode( client, MODE_VELCAP );
    
    return Plugin_Handled;
}