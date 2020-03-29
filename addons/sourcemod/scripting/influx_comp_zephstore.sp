#include <sourcemod>

// Zeph store
#include <store>

// Influx
#include <influx/core>



ConVar g_ConVar_CreditsNormal = null;

public Plugin:myinfo =
{
    name = "Bhop Map Completion Credits",
    author = "",
    description = "Give ZephStore Credits on Completion",
    version = "",
    url = ""
};

public OnPluginStart()
{
    g_ConVar_CreditsNormal = CreateConVar( "sm_bhop_credits", "1.0", "Credits given when a player finishes a map.", FCVAR_NOTIFY );
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    int credits = g_ConVar_CreditsNormal.IntValue;

    Store_SetClientCredits( client, Store_GetClientCredits( client ) + credits );

    PrintToChat( client, "\x03You received \x01%i\x03 credits for completing the map!", credits );
}
