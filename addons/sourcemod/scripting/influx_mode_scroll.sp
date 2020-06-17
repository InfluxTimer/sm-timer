#include <sourcemod>
#include <sdkhooks>

#include <influx/core>
#include <influx/stocks_core>


#undef REQUIRE_PLUGIN
#include <influx/fpscheck>


//#define DEBUG_THINK


float g_flAirAccelerate = 100.0;

// CONVARS
ConVar g_ConVar_AirAccelerate;
ConVar g_ConVar_EnableBunnyhopping;

ConVar g_ConVar_Scroll_AirAccelerate;


bool g_bLib_FpsCheck;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Mode - Scroll",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CONVARS
    if ( (g_ConVar_AirAccelerate = FindConVar( "sv_airaccelerate" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_airaccelerate!" );
    }
    
    if ( (g_ConVar_EnableBunnyhopping = FindConVar( "sv_enablebunnyhopping" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_enablebunnyhopping!" );
    }
    
    
    g_ConVar_Scroll_AirAccelerate = CreateConVar( "influx_scroll_airaccelerate", "100", "", FCVAR_NOTIFY );
    g_ConVar_Scroll_AirAccelerate.AddChangeHook( E_CvarChange_Scroll_AA );
    
    AutoExecConfig( true, "mode_scroll", "influx" );
    
    
    // CMDS
    RegConsoleCmd( "sm_scroll", Cmd_Mode_Scroll, INF_NAME..." - Change your mode to Scroll." );
    RegConsoleCmd( "sm_scrll", Cmd_Mode_Scroll, "" );
    RegConsoleCmd( "sm_scrl", Cmd_Mode_Scroll, "" );
    
    
    g_bLib_FpsCheck = LibraryExists( INFLUX_LIB_FPSCHECK );
}

public void OnAllPluginsLoaded()
{
    AddMode();
    
    if ( g_bLib_FpsCheck )
    {
        Influx_AddFpsCheck( MODE_SCROLL );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveMode( MODE_SCROLL );
    
    if ( g_bLib_FpsCheck )
    {
        Influx_RemoveFpsCheck( MODE_SCROLL );
    }
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_FPSCHECK ) ) g_bLib_FpsCheck = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_FPSCHECK ) ) g_bLib_FpsCheck = false;
}

public void Influx_OnRequestModes()
{
    AddMode();
}

stock void AddMode()
{
    if ( !Influx_AddMode( MODE_SCROLL, "Scroll", "Scroll", "scrl" ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add mode! (%i)", MODE_SCROLL );
    }
}

public void Influx_OnRequestFpsChecks()
{
    Influx_AddFpsCheck( MODE_SCROLL );
}

public Action Influx_OnClientModeChange( int client, int mode, int lastmode )
{
    if ( mode == MODE_SCROLL )
    {
        UnhookThinks( client );
        
        
        if ( !Inf_SDKHook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client ) )
        {
            return Plugin_Handled;
        }
        
        Inf_SendConVarValueFloat( client, g_ConVar_AirAccelerate, g_ConVar_Scroll_AirAccelerate.FloatValue );
        Inf_SendConVarValueBool( client, g_ConVar_EnableBunnyhopping, true );
    }
    else if ( lastmode == MODE_SCROLL )
    {
        UnhookThinks( client );
    }
    
    return Plugin_Continue;
}

stock void UnhookThinks( int client )
{
    SDKUnhook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client );
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "scroll", false )
    ||  StrEqual( szArg, "scrl", false ) )
    {
        value = MODE_SCROLL;
        type = SEARCH_MODE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public void E_CvarChange_Scroll_AA( ConVar convar, const char[] oldval, const char[] newval )
{
    g_flAirAccelerate = convar.FloatValue;
}

public void E_PreThinkPost_Client( int client )
{
#if defined DEBUG_THINK
    PrintToServer( INF_DEBUG_PRE..."PreThinkPost - Scroll (aa: %.0f)", g_flAirAccelerate );
#endif
    
    if ( Influx_GetClientMode( client ) != MODE_SCROLL )
    {
        RequestFrame( UnhookThinksCb, GetClientUserId( client ) );
        return;
    }
    

    g_ConVar_AirAccelerate.FloatValue = g_flAirAccelerate;
    g_ConVar_EnableBunnyhopping.BoolValue = true;
}

public void UnhookThinksCb( int userid ) // Can't unhook inside hook
{
    int client = GetClientOfUserId( userid );
    if ( client <= 0 || !IsClientInGame( client ) )
        return;


    UnhookThinks( client );
}

public Action Cmd_Mode_Scroll( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientMode( client, MODE_SCROLL );
    
    return Plugin_Handled;
}