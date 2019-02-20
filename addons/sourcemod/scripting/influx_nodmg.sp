#include <sourcemod>
#include <cstrike>
#include <sdkhooks>

#include <influx/core>


ConVar g_ConVar_Type;


bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - No Damage",
    description = "Disable players getting hurt fee fees :(",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    g_bLate = late;
}

public void OnPluginStart()
{
    // CONVARS
    g_ConVar_Type = CreateConVar( "influx_nodmg_type", "2", "0 = Don't do anything, 1 = Only block fall-damage, 2 = Block all damage", FCVAR_NOTIFY, true, 0.0, true, 2.0 );
    g_ConVar_Type.AddChangeHook( E_ConVarChanged_Type );
    
    AutoExecConfig( true, "nodmg", "influx" );
    
    
    // EVENTS
    HookEvent( "player_spawn", E_PlayerSpawn );
    
    
    if ( g_bLate )
    {
        UpdateAllClients( false );
    }
}

public void OnPluginEnd()
{
    UpdateAllClients( true );
}

public void E_ConVarChanged_Type( ConVar convar, const char[] oldValue, const char[] newValue )
{
    UpdateAllClients( false );
}

public void E_PlayerSpawn( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    
    RequestFrame( E_PlayerSpawn_Delay, GetClientUserId( client ) );
}

public void E_PlayerSpawn_Delay( int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    if ( !IsPlayerAlive( client ) ) return;
    
    
    UpdateClient( client, false );
}

public Action OnTakeDamageAlive_Client( int victim, int &attacker, int &inflictor, float &damage, int &damagetype )
{
    if ( damagetype == DMG_FALL )
    {
        damage = 0.0;
        return Plugin_Changed;
    }
    
    return Plugin_Continue;
}

stock void UpdateClient( int client, bool bAllowDmg )
{
    int val = g_ConVar_Type.IntValue;
    
    if ( !bAllowDmg && val == 1 )
    {
        UnhookDamage( client );
        HookDamage( client );
    }
    else
    {
        UnhookDamage( client );
    }

    
    // Events only so we still have stamina affecting us.
    if ( !bAllowDmg && val == 2 )
    {
        SetTakeDamage( client, false );
    }
    else
    {
        SetTakeDamage( client, true );
    }
}

stock void UpdateAllClients( bool bAllowDmg )
{
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame( i ) )
        {
            UpdateClient( i, bAllowDmg );
        }
    }
}

stock void HookDamage( int client )
{
    Inf_SDKHook( client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive_Client );
}

stock void UnhookDamage( int client )
{
    SDKUnhook( client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive_Client );
}

stock void SetTakeDamage( int client, bool bAllowDmg )
{
    SetEntProp( client, Prop_Data, "m_takedamage", bAllowDmg ? 2 : 1 );
}