#include <sourcemod>
#include <sdktools>

#include <influx/core>
#include <influx/stocks_core>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Style - W-Only",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_w-only", Cmd_Style_W, "Change your style to w-only." );
    RegConsoleCmd( "sm_wonly", Cmd_Style_W, "" );
    RegConsoleCmd( "sm_w", Cmd_Style_W, "" );
}

public void OnAllPluginsLoaded()
{
    if ( !Influx_AddStyle( STYLE_W, "W-Only", "W-Only", "w" ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add style!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveStyle( STYLE_W );
}

public void Influx_OnRequestStyles()
{
    OnAllPluginsLoaded();
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "w", false )
    ||  StrEqual( szArg, "wonly", false )
    ||  StrEqual( szArg, "w-only", false ) )
    {
        value = STYLE_W;
        type = SEARCH_STYLE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Cmd_Style_W( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientStyle( client, STYLE_W );
    
    return Plugin_Handled;
}

public Action Influx_OnCheckClientStyle( int client, int style, float vel[3] )
{
    if ( style != STYLE_W ) return Plugin_Continue;
    
#define FWD     0
#define SIDE    1
    
    if ( vel[SIDE] != 0.0 )
    {
        vel[SIDE] = 0.0;
    }
    
    if ( vel[FWD] < 0.0 )
    {
        vel[FWD] = 0.0;
    }
    
    return Plugin_Stop;
}