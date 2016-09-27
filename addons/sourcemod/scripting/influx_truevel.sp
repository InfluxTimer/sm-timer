#include <sourcemod>

#include <influx/core>
#include <influx/hud>
#include <influx/truevel>

#undef REQUIRE_PLUGIN
#include <influx/help>


bool g_bTruevel[INF_MAXPLAYERS];


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - True Velocity",
    description = "Allow users to show true velocity.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_TRUEVEL );
    
    
    // NATIVES
    CreateNative( "Influx_IsClientUsingTruevel", Native_IsClientUsingTruevel );
}

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_truevel", Cmd_Truevel );
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "truevel", "Toggle true velocity displaying." );
}

public void OnClientPutInServer( int client )
{
    g_bTruevel[client] = false;
}

public Action Cmd_Truevel( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    g_bTruevel[client] = !g_bTruevel[client];
    
    
    Influx_PrintToChat( _, client, "Truevel: {MAINCLR1}%s{CHATCLR}!", g_bTruevel[client] ? "ON" : "OFF" );
    
    return Plugin_Handled;
}

// NATIVES
public int Native_IsClientUsingTruevel( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return g_bTruevel[client];
}