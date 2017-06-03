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
    name = INF_NAME..." - Style - Real Half-Sideways",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_rhsw", Cmd_Style_RHSW, "Change your style to Real Half-Sideways." );
    RegConsoleCmd( "sm_realhalfsideways", Cmd_Style_RHSW );
    RegConsoleCmd( "sm_surfhsw", Cmd_Style_RHSW );
}

public void OnAllPluginsLoaded()
{
    if ( !Influx_AddStyle( STYLE_RHSW, "Real HSW", "Real HSW", "rhsw" ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add style!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveStyle( STYLE_RHSW );
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
    if (StrEqual( szArg, "rhsw", false )
    ||  StrEqual( szArg, "realhsw", false )
    ||  StrEqual( szArg, "surfhsw", false )
    ||  StrEqual( szArg, "realhalfsideways", false )
    ||  StrEqual( szArg, "real-halfsideways", false ) )
    {
        value = STYLE_RHSW;
        type = SEARCH_STYLE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Cmd_Style_RHSW( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientStyle( client, STYLE_RHSW );
    
    return Plugin_Handled;
}

public Action Influx_OnCheckClientStyle( int client, int style, float vel[3] )
{
    if ( style != STYLE_RHSW ) return Plugin_Continue;
    
#define FWD     0
#define SIDE    1
    
    if ( vel[FWD] != 0.0 && vel[SIDE] == 0.0 )
    {
        vel[FWD] = 0.0;
    }
    else if ( vel[SIDE] != 0.0 && vel[FWD] == 0.0 )
    {
        vel[SIDE] = 0.0;
    }
    
    if ( g_iSide[client] == SIDE_NONE )
    {
        // Enable WD and SA
        if ( (vel[FWD] > 0.0 && vel[SIDE] > 0.0) || (vel[FWD] < 0.0 && vel[SIDE] < 0.0) )
        {
            g_iSide[client] = SIDE_1;
        }
        // Enable WA and SD
        else if ( (vel[FWD] > 0.0 && vel[SIDE] < 0.0) || (vel[FWD] < 0.0 && vel[SIDE] > 0.0) )
        {
            g_iSide[client] = SIDE_2;
        }
    }
    
    // Disable WA and SD
    if ( g_iSide[client] == SIDE_1 )
    {
        if ( vel[FWD] > 0.0 && vel[SIDE] < 0.0 )
        {
            vel[FWD] = 0.0;
            vel[SIDE] = 0.0;
        }
        else if ( vel[FWD] < 0.0 && vel[SIDE] > 0.0 )
        {
            vel[FWD] = 0.0;
            vel[SIDE] = 0.0;
        }
    }
    // Disable WD and SA
    else if ( g_iSide[client] == SIDE_2 )
    {
        if ( vel[FWD] > 0.0 && vel[SIDE] > 0.0 )
        {
            vel[FWD] = 0.0;
            vel[SIDE] = 0.0;
        }
        else if ( vel[FWD] < 0.0 && vel[SIDE] < 0.0 )
        {
            vel[FWD] = 0.0;
            vel[SIDE] = 0.0;
        }
    }
    
    return Plugin_Stop;
}