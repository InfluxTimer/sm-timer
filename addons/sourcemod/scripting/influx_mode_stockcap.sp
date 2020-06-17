#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/stocks_core>


#undef REQUIRE_PLUGIN
#include <influx/fpscheck>


//#define DEBUG_THINK


float g_flAirAccelerate = 100.0;


ConVar g_ConVar_StockCap_AirAccelerate;
ConVar g_ConVar_AirAccelerate;
ConVar g_ConVar_EnableBunnyhopping;


bool g_bLib_FpsCheck;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Mode - Stock Cap",
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
    
    
    g_ConVar_StockCap_AirAccelerate = CreateConVar( "influx_stockcap_airaccelerate", "100", "", FCVAR_NOTIFY );
    g_ConVar_StockCap_AirAccelerate.AddChangeHook( E_CvarChange_StockCap_AA );
    
    AutoExecConfig( true, "mode_stockcap", "influx" );
    
    
    RegConsoleCmd( "sm_stock", Cmd_Mode_StockCap, INF_NAME..." - Change your mode to stock cap." );
    
    
    g_bLib_FpsCheck = LibraryExists( INFLUX_LIB_FPSCHECK );
}

public void OnAllPluginsLoaded()
{
    AddMode();
    
    if ( g_bLib_FpsCheck )
    {
        Influx_AddFpsCheck( MODE_STOCKCAP );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveMode( MODE_STOCKCAP );
    
    if ( g_bLib_FpsCheck )
    {
        Influx_RemoveFpsCheck( MODE_STOCKCAP );
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

public void OnClientDisconnect( int client )
{
    UnhookThinks( client );
}

public void Influx_OnRequestModes()
{
    AddMode();
}

stock void AddMode()
{
    if ( !Influx_AddMode( MODE_STOCKCAP, "Stock Cap", "Stock", "stock" ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add mode! (%i)", MODE_STOCKCAP );
    }
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "stockcap", false )
    ||  StrEqual( szArg, "cap", false ) )
    {
        value = MODE_STOCKCAP;
        type = SEARCH_MODE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public void Influx_OnRequestFpsChecks()
{
    Influx_AddFpsCheck( MODE_STOCKCAP );
}

public Action Influx_OnClientModeChange( int client, int mode, int lastmode )
{
    if ( mode == MODE_STOCKCAP )
    {
        UnhookThinks( client );
        
        
        if ( !Inf_SDKHook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client ) )
        {
            return Plugin_Handled;
        }
        
        Inf_SendConVarValueFloat( client, g_ConVar_AirAccelerate, g_ConVar_StockCap_AirAccelerate.FloatValue );
        Inf_SendConVarValueBool( client, g_ConVar_EnableBunnyhopping, false );
    }
    else if ( lastmode == MODE_STOCKCAP )
    {
        UnhookThinks( client );
        
        Inf_SendConVarValueBool( client, g_ConVar_EnableBunnyhopping, true );
    }
    
    return Plugin_Continue;
}

stock void UnhookThinks( int client )
{
    SDKUnhook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client );
}

public void E_CvarChange_StockCap_AA( ConVar convar, const char[] oldval, const char[] newval )
{
    g_flAirAccelerate = convar.FloatValue;
}

public void E_PreThinkPost_Client( int client )
{
#if defined DEBUG_THINK
    PrintToServer( INF_DEBUG_PRE..."PreThinkPost - StockCap (aa: %.0f)", g_flAirAccelerate );
#endif
    
    if ( Influx_GetClientMode( client ) != MODE_STOCKCAP )
    {
        RequestFrame( UnhookThinksCb, GetClientUserId( client ) );
        return;
    }

    g_ConVar_AirAccelerate.FloatValue = g_flAirAccelerate;
    g_ConVar_EnableBunnyhopping.BoolValue = false;
}

public void UnhookThinksCb( int userid ) // Can't unhook inside hook
{
    int client = GetClientOfUserId( userid );
    if ( client <= 0 || !IsClientInGame( client ) )
        return;


    UnhookThinks( client );
}

public Action Cmd_Mode_StockCap( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientMode( client, MODE_STOCKCAP );
    
    return Plugin_Handled;
}