#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/zones>
#include <influx/zones_autobhop>

#include <msharedutil/arrayvec>


bool g_bInAutoZone[INF_MAXPLAYERS];


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Zones | Autobhop",
    description = "Allows player to autobhop in this zone.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_ZONES_AUTO );
}

public void OnPluginStart()
{
}

public void OnAllPluginsLoaded()
{
    AddZoneType();
}

public void Influx_OnRequestZoneTypes()
{
    AddZoneType();
}

stock void AddZoneType()
{
    if ( !Influx_RegZoneType( ZONETYPE_AUTOBHOP, "Autobhop", "autobhop", false ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't register zone type!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveZoneType( ZONETYPE_AUTOBHOP );
}

public void OnClientPutInServer( int client )
{
    g_bInAutoZone[client] = false;
}

public void Influx_OnZoneSpawned( int zoneid, ZoneType_t zonetype, int ent )
{
    if ( zonetype != ZONETYPE_AUTOBHOP ) return;

    
    SDKHook( ent, SDKHook_StartTouchPost, E_StartTouchPost_Autobhop );
    SDKHook( ent, SDKHook_EndTouchPost, E_EndTouchPost_Autobhop );
    
    Inf_SetZoneProp( ent, zoneid );
}

public void Influx_OnZoneCreated( int client, int zoneid, ZoneType_t zonetype )
{
    //if ( zonetype != ZONETYPE_AUTOBHOP ) return;
}

public void Influx_OnZoneDeleted( int zoneid, ZoneType_t zonetype )
{
    //if ( zonetype != ZONETYPE_AUTOBHOP ) return;
}

public void E_StartTouchPost_Autobhop( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
    UnhookThinks( activator );
    
    Inf_SDKHook( activator, SDKHook_PreThinkPost, E_PreThinkPost_Client );
    
    g_bInAutoZone[activator] = true;
}

public void E_EndTouchPost_Autobhop( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    
    UnhookThinks( activator );
    
    g_bInAutoZone[activator] = false;
}

public void E_PreThinkPost_Client( int client )
{
    if ( !g_bInAutoZone[client] && !IsPlayerAlive( client ) )
    {
        UnhookThinks( client );
        return;
    }
    
    
    int buttons = GetEntProp( client, Prop_Data, "m_nOldButtons" );
    
    if ( buttons & IN_JUMP )
    {
        SetEntProp( client, Prop_Data, "m_nOldButtons", buttons & ~IN_JUMP );
    }
}

stock void UnhookThinks( int client )
{
    SDKUnhook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client );
}