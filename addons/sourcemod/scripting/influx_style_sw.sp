#include <sourcemod>
#include <sdktools>

#include <influx/core>
#include <influx/stocks_core>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Style - Sideways",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_sideways", Cmd_Style_SW, "Change your style to sideways." );
    RegConsoleCmd( "sm_sw", Cmd_Style_SW, "" );
}

public void OnAllPluginsLoaded()
{
    if ( !Influx_AddStyle( STYLE_SW, "Sideways", "Sideways", "sw" ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add style!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveStyle( STYLE_SW );
}

public void Influx_OnRequestStyles()
{
    OnAllPluginsLoaded();
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "sw", false )
    ||  StrEqual( szArg, "sideways", false ) )
    {
        value = STYLE_SW;
        type = SEARCH_STYLE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Cmd_Style_SW( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientStyle( client, STYLE_SW );
    
    return Plugin_Handled;
}

public Action Influx_OnCheckClientStyle( int client, int style, float vel[3] )
{
    if ( style != STYLE_SW ) return Plugin_Continue;
    
#define FWD     0
#define SIDE    1
    
    if ( vel[SIDE] != 0.0 )
    {
        vel[SIDE] = 0.0;
    }
    
    return Plugin_Stop;
}