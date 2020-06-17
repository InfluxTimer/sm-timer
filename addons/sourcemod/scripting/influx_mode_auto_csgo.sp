#include <sourcemod>
#include <sdkhooks>
#include <cstrike>

#include <influx/core>


//#define DEBUG_THINK


float g_flAirAccelerate;


// CONVARS
ConVar g_ConVar_AirAccelerate;
ConVar g_ConVar_EnableBunnyhopping;
ConVar g_ConVar_AutoBhop;

ConVar g_ConVar_Auto_AirAccelerate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Mode - Auto",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    if ( GetEngineVersion() != Engine_CSGO )
    {
        FormatEx( szError, error_len, "This plugin is for CS:GO only. You can safely remove this plugin file." );
        return APLRes_SilentFailure;
    }
    
    return APLRes_Success;
}

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
    
    
    if ( (g_ConVar_AutoBhop = FindConVar( "sv_autobunnyhopping" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_autobunnyhopping!" );
    }
    
    g_ConVar_AutoBhop.Flags &= ~(FCVAR_REPLICATED | FCVAR_NOTIFY);
    
    
    
    g_ConVar_Auto_AirAccelerate = CreateConVar( "influx_auto_airaccelerate", "1000", "", FCVAR_NOTIFY );
    g_ConVar_Auto_AirAccelerate.AddChangeHook( E_CvarChange_Auto_AA );
    
    g_flAirAccelerate = g_ConVar_Auto_AirAccelerate.FloatValue;
    
    
    AutoExecConfig( true, "mode_auto_csgo", "influx" );
    
    
    // CMDS
    RegConsoleCmd( "sm_auto", Cmd_Mode_Auto, INF_NAME..." - Change your mode to autobhop." );
    RegConsoleCmd( "sm_autobhop", Cmd_Mode_Auto, "" );
    RegConsoleCmd( "sm_abhop", Cmd_Mode_Auto, "" );
    RegConsoleCmd( "sm_ahop", Cmd_Mode_Auto, "" );
    RegConsoleCmd( "sm_a", Cmd_Mode_Auto, "" );
}

public void OnAllPluginsLoaded()
{
    AddMode();
}

public void OnPluginEnd()
{
    Influx_RemoveMode( MODE_AUTO );
    
    
    g_ConVar_AutoBhop.Flags |= (FCVAR_REPLICATED | FCVAR_NOTIFY);
}

public void Influx_OnRequestModes()
{
    AddMode();
}

stock void AddMode()
{
    if ( !Influx_AddMode( MODE_AUTO, "Autobhop", "Auto", "auto", 260.0 ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add mode! (%i)", MODE_AUTO );
    }
}

public Action Influx_OnClientModeChange( int client, int mode, int lastmode )
{
    if ( mode == MODE_AUTO )
    {
        UnhookThinks( client );
        
        
        if ( !Inf_SDKHook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client ) )
        {
            return Plugin_Handled;
        }
        
        if ( !Inf_SDKHook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client ) )
        {
            UnhookThinks( client );
            return Plugin_Handled;
        }
        
        
        Inf_SendConVarValueFloat( client, g_ConVar_AirAccelerate, g_ConVar_Auto_AirAccelerate.FloatValue );
        Inf_SendConVarValueBool( client, g_ConVar_EnableBunnyhopping, true );
        Inf_SendConVarValueBool( client, g_ConVar_AutoBhop, true );
    }
    else if ( lastmode == MODE_AUTO )
    {
        UnhookThinks( client );
        
        Inf_SendConVarValueBool( client, g_ConVar_AutoBhop, false );
    }
    
    return Plugin_Continue;
}

stock void UnhookThinks( int client )
{
    SDKUnhook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client );
    SDKUnhook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "auto", false )
    ||  StrEqual( szArg, "autobhop", false )
    ||  StrEqual( szArg, "auto-bhop", false )
    ||  StrEqual( szArg, "autobunnyhop", false ) )
    {
        value = MODE_AUTO;
        type = SEARCH_MODE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public void E_CvarChange_Auto_AA( ConVar convar, const char[] oldval, const char[] newval )
{
    g_flAirAccelerate = convar.FloatValue;
}

public void E_PreThinkPost_Client( int client )
{
#if defined DEBUG_THINK
    PrintToServer( INF_DEBUG_PRE..."PreThinkPost - Auto CS:GO (aa: %.0f)", g_flAirAccelerate );
#endif
    
    if ( Influx_GetClientMode( client ) != MODE_AUTO )
    {
        RequestFrame( UnhookThinksCb, GetClientUserId( client ) );
        return;
    }
    

    g_ConVar_AirAccelerate.FloatValue = g_flAirAccelerate;
    g_ConVar_EnableBunnyhopping.BoolValue = true;
    g_ConVar_AutoBhop.BoolValue = true;
}

public void E_PostThinkPost_Client( int client )
{
#if defined DEBUG_THINK
    PrintToServer( INF_DEBUG_PRE..."PostThinkPost - Auto CS:GO (aa: %.0f)", g_flAirAccelerate );
#endif

    g_ConVar_AutoBhop.BoolValue = false;
	
	
    if ( Influx_GetClientMode( client ) != MODE_AUTO )
    {
        RequestFrame( UnhookThinksCb, GetClientUserId( client ) );
        return;
    }
}

public void UnhookThinksCb( int userid ) // Can't unhook inside hook
{
    int client = GetClientOfUserId( userid );
    if ( client <= 0 || !IsClientInGame( client ) )
        return;


    UnhookThinks( client );
}

public Action Cmd_Mode_Auto( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientMode( client, MODE_AUTO );
    
    return Plugin_Handled;
}