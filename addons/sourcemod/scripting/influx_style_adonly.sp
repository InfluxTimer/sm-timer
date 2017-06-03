#include <sourcemod>
#include <sdktools>

#include <influx/core>
#include <influx/stocks_core>


enum
{
    SIDE_NONE = 0,
    SIDE_1,
    SIDE_2
};


int g_iSide[INF_MAXPLAYERS];


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Style - A/D-Only",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_ad-only", Cmd_Style_AD, "Change your style to A/D-Only." );
    RegConsoleCmd( "sm_adonly", Cmd_Style_AD );
    RegConsoleCmd( "sm_ad", Cmd_Style_AD, "" );
    RegConsoleCmd( "sm_aonly", Cmd_Style_AD, "" );
    RegConsoleCmd( "sm_a-only", Cmd_Style_AD, "" );
    RegConsoleCmd( "sm_donly", Cmd_Style_AD, "" );
    RegConsoleCmd( "sm_d-only", Cmd_Style_AD, "" );
}

public void OnAllPluginsLoaded()
{
    if ( !Influx_AddStyle( STYLE_AD, "A/D-Only", "A/D-Only", "ad" ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add style!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveStyle( STYLE_AD );
}

public void Influx_OnRequestStyles()
{
    OnAllPluginsLoaded();
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    g_iSide[client] = SIDE_NONE;
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "a-only", false )
    ||  StrEqual( szArg, "d-only", false )
    ||  StrEqual( szArg, "aonly", false )
    ||  StrEqual( szArg, "donly", false )
    ||  StrEqual( szArg, "adonly", false )
    ||  StrEqual( szArg, "a/d-only", false ) )
    {
        value = STYLE_AD;
        type = SEARCH_STYLE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Cmd_Style_AD( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientStyle( client, STYLE_AD );
    
    return Plugin_Handled;
}

public Action Influx_OnCheckClientStyle( int client, int style, float vel[3] )
{
    if ( style != STYLE_AD ) return Plugin_Continue;
    
#define FWD     0
#define SIDE    1
    
    if ( vel[FWD] != 0.0 )
    {
        vel[FWD] = 0.0;
    }
    
    if ( g_iSide[client] == SIDE_NONE )
    {
        if ( vel[SIDE] != 0.0 )
        {
            g_iSide[client] = ( vel[SIDE] > 0.0 ) ? SIDE_1 : SIDE_2;
        }
    }
    else
    {
        if ( g_iSide[client] == SIDE_1 && vel[SIDE] < 0.0 )
        {
            vel[SIDE] = 0.0;
        }
        else if ( g_iSide[client] == SIDE_2 && vel[SIDE] > 0.0 )
        {
            vel[SIDE] = 0.0;
        }
    }
    
    return Plugin_Stop;
}