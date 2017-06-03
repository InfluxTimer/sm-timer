#include <sourcemod>
#include <sdktools>

#include <influx/core>
#include <influx/stocks_core>

#include <msharedutil/ents>



//#define DEBUG



#define MAX_DOT         -0.8


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Style - Backwards",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_backwards", Cmd_STYLE_BWD, "Change your style to backwards." );
    RegConsoleCmd( "sm_backward", Cmd_STYLE_BWD, "" );
    RegConsoleCmd( "sm_bwds", Cmd_STYLE_BWD, "" );
    RegConsoleCmd( "sm_bwd", Cmd_STYLE_BWD, "" );
}

public void OnAllPluginsLoaded()
{
    if ( !Influx_AddStyle( STYLE_BWD, "Backwards", "Backwards", "bwd" ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add style!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveStyle( STYLE_BWD );
}

public void Influx_OnRequestStyles()
{
    OnAllPluginsLoaded();
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "backwards", false )
    ||  StrEqual( szArg, "bwds", false )
    ||  StrEqual( szArg, "bwd", false ) )
    {
        value = STYLE_BWD;
        type = SEARCH_STYLE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Influx_OnCheckClientStyle( int client, int style, float vel[3] )
{
    if ( style != STYLE_BWD ) return Plugin_Continue;
    
    
    decl Float:eye[3];
    decl Float:velocity[3];
    
    GetClientEyeAngles( client, eye );
    
    eye[0] = Cosine( DegToRad( eye[1] ) );
    eye[1] = Sine( DegToRad( eye[1] ) );
    eye[2] = 0.0;
    
    GetEntityVelocity( client, velocity );
    
    velocity[2] = 0.0;
    
    
    float len = SquareRoot( velocity[0] * velocity[0] + velocity[1] * velocity[1] );
    
    velocity[0] /= len;
    velocity[1] /= len;
    
    
    float val = GetVectorDotProduct( eye, velocity );
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Dot product: %.1f", val );
#endif
    
    // They're not looking backwards enough! GET EM!
    if ( val > MAX_DOT )
    {
        vel[0] = 0.0;
        vel[1] = 0.0;
        vel[2] = 0.0;
    }
    
    return Plugin_Stop;
}

public Action Cmd_STYLE_BWD( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientStyle( client, STYLE_BWD );
    
    return Plugin_Handled;
}