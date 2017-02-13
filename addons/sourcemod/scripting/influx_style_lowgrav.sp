#include <sourcemod>
#include <sdktools>

#include <influx/core>
#include <influx/stocks_core>


//#define DEBUG_THINK


ConVar g_ConVar_Gravity;

ConVar g_ConVar_GravMult;


float g_flDefaultGravity;
float g_flLowGravGravity;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Style - Low Gravity",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CONVARS
    if ( (g_ConVar_Gravity = FindConVar( "sv_gravity" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_gravity!" );
    }
    
    g_ConVar_Gravity.Flags &= ~(FCVAR_REPLICATED | FCVAR_NOTIFY);
    
    
    
    
    
    
    g_ConVar_GravMult = CreateConVar( "influx_style_lowgrav_mult", "0.5", "Gravity multiplier when using low gravity style.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_GravMult.AddChangeHook( E_ConVarChanged_GravMult );
    
    
    g_flDefaultGravity = 800.0;
    g_flLowGravGravity = g_flDefaultGravity * g_ConVar_GravMult.FloatValue;
    
    
    AutoExecConfig( true, "style_lowgrav", "influx" );
    
    
    // CMDS
    RegConsoleCmd( "sm_lowgravity", Cmd_Style_LowGrav, "Change your style to low gravity." );
    RegConsoleCmd( "sm_lowgrav", Cmd_Style_LowGrav, "" );
    RegConsoleCmd( "sm_gravity", Cmd_Style_LowGrav, "" );
    RegConsoleCmd( "sm_grav", Cmd_Style_LowGrav, "" );
    RegConsoleCmd( "sm_lowg", Cmd_Style_LowGrav, "" );
    RegConsoleCmd( "sm_low", Cmd_Style_LowGrav, "" );
    RegConsoleCmd( "sm_lg", Cmd_Style_LowGrav, "" );
}

public void OnAllPluginsLoaded()
{
    if ( !Influx_AddStyle( STYLE_LOWGRAV, "Low Gravity", "LOWGRAV" ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add style!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveStyle( STYLE_LOWGRAV );
}

public void E_ConVarChanged_GravMult( ConVar convar, const char[] oldValue, const char[] newValue )
{
    g_flLowGravGravity = g_flDefaultGravity * g_ConVar_GravMult.FloatValue;
    
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame( i ) && Influx_GetClientStyle( i ) == STYLE_LOWGRAV )
        {
            Inf_SendConVarValueFloat( i, g_ConVar_Gravity, g_flLowGravGravity );
        }
    }
}

public void Influx_OnRequestStyles()
{
    OnAllPluginsLoaded();
}

public Action Influx_OnClientStyleChange( int client, int style, int laststyle )
{
    if ( style == STYLE_LOWGRAV )
    {
        if ( !Inf_SDKHook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client ) )
        {
            return Plugin_Handled;
        }
        
        if ( !Inf_SDKHook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client ) )
        {
            UnhookThinks( client );
            return Plugin_Handled;
        }
        
        
        Inf_SendConVarValueFloat( client, g_ConVar_Gravity, g_flLowGravGravity );
    }
    else if ( laststyle == STYLE_LOWGRAV )
    {
        UnhookThinks( client );
        
        Inf_SendConVarValueFloat( client, g_ConVar_Gravity, g_flDefaultGravity );
    }
    
    return Plugin_Continue;
}

stock void UnhookThinks( int client )
{
    SDKUnhook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client );
    SDKUnhook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
}

public void E_PreThinkPost_Client( int client )
{
#if defined DEBUG_THINK
    PrintToServer( INF_DEBUG_PRE..."PreThinkPost - Low Grav (grav: %.0f | low grav: %.0f)", g_flDefaultGravity, g_flLowGravGravity );
#endif
    
    g_ConVar_Gravity.FloatValue = g_flLowGravGravity;
}

public void E_PostThinkPost_Client( int client )
{
#if defined DEBUG_THINK
    PrintToServer( INF_DEBUG_PRE..."PostThinkPost - Low Grav (grav: %.0f | low grav: %.0f)", g_flDefaultGravity, g_flLowGravGravity );
#endif
    
    g_ConVar_Gravity.FloatValue = g_flDefaultGravity;
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "lowgravity", false )
    ||  StrEqual( szArg, "gravity", false )
    ||  StrEqual( szArg, "grav", false )
    ||  StrEqual( szArg, "low", false ) )
    {
        value = STYLE_LOWGRAV;
        type = SEARCH_STYLE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Influx_OnCheckClientStyle( int client, int style, float vel[3] )
{
    if ( style != STYLE_LOWGRAV ) return Plugin_Continue;
    
    
    return Plugin_Stop;
}

public Action Cmd_Style_LowGrav( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientStyle( client, STYLE_LOWGRAV );
    
    return Plugin_Handled;
}