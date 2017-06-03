#include <sourcemod>
#include <sdktools>

#include <influx/core>
#include <influx/stocks_core>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Style - Half-Sideways",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_hsw", Cmd_Style_HSW, "Change your style to Half-Sideways." );
    RegConsoleCmd( "sm_half-sideways", Cmd_Style_HSW );
    RegConsoleCmd( "sm_halfsideways", Cmd_Style_HSW );
    RegConsoleCmd( "sm_halfsw", Cmd_Style_HSW );
}

public void OnAllPluginsLoaded()
{
    if ( !Influx_AddStyle( STYLE_HSW, "Half-Sideways", "Half-SW", "hsw" ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add style!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveStyle( STYLE_HSW );
}

public void Influx_OnRequestStyles()
{
    OnAllPluginsLoaded();
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "hsw", false )
    ||  StrEqual( szArg, "halfsideways", false )
    ||  StrEqual( szArg, "half-sideways", false ) )
    {
        value = STYLE_HSW;
        type = SEARCH_STYLE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Cmd_Style_HSW( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientStyle( client, STYLE_HSW );
    
    return Plugin_Handled;
}

public Action Influx_OnCheckClientStyle( int client, int style, float vel[3] )
{
    if ( style != STYLE_HSW ) return Plugin_Continue;
    
#define FWD     0
#define SIDE    1
    
    if ( vel[FWD] < 0.0 )
    {
        vel[FWD] = 0.0;
    }
    
    if ((vel[SIDE] != 0.0 && vel[FWD] <= 0.0)
    ||  (vel[SIDE] == 0.0 && vel[FWD] != 0.0) )
    {
        vel[FWD] = 0.0;
        vel[SIDE] = 0.0;
    }
    
    return Plugin_Stop;
}