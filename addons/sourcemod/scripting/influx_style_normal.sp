#include <sourcemod>

#include <influx/core>
#include <influx/stocks_core>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Style - Normal",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_normal", Cmd_Style_Normal, INF_NAME..." - Change your style to normal." );
    RegConsoleCmd( "sm_default", Cmd_Style_Normal, "" );
    RegConsoleCmd( "sm_n", Cmd_Style_Normal, "" );
}

public void OnAllPluginsLoaded()
{
    if ( !Influx_AddStyle( STYLE_NORMAL, "Normal", "Normal", "nrml", false ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add style!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveStyle( STYLE_NORMAL );
}

public void Influx_OnRequestStyles()
{
    OnAllPluginsLoaded();
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "normal", false )
    ||  StrEqual( szArg, "nrml", false ) )
    {
        value = STYLE_NORMAL;
        type = SEARCH_STYLE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Cmd_Style_Normal( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientStyle( client, STYLE_NORMAL );
    
    return Plugin_Handled;
}

public Action Influx_OnCheckClientStyle( int client, int style, float vel[3] )
{
    if ( style != STYLE_NORMAL ) return Plugin_Continue;
    
    return Plugin_Stop;
}