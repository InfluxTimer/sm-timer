#include <sourcemod>
#include <sdktools>

#include <influx/core>
#include <influx/stocks_core>




ConVar g_ConVar_GravMult;


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
    g_ConVar_GravMult = CreateConVar( "influx_style_lowgrav_mult", "0.5", "Gravity multiplier when using low gravity style.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_GravMult.AddChangeHook( E_ConVarChanged_GravMult );
    
    
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
    float value = g_ConVar_GravMult.FloatValue;
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame( i ) && Influx_GetClientStyle( i ) == STYLE_LOWGRAV )
        {
            SetEntityGravity( i, value );
        }
    }
}

public void Influx_OnRequestStyles()
{
    OnAllPluginsLoaded();
}

public void Influx_OnClientStyleChangePost( int client, int style )
{
    if ( style == STYLE_LOWGRAV )
    {
        SetEntityGravity( client, g_ConVar_GravMult.FloatValue );
    }
    else
    {
        SetEntityGravity( client, 1.0 );
    }
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