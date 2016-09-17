#include <sourcemod>
#include <sdktools_hooks>
#include <sdkhooks>
#include <cstrike>

#include <influx/core>
#include <influx/stocks_core>

#include <msharedutil/ents>


//#define DEBUG_THINK


float g_flAirAccelerate = 1000.0;


ConVar g_ConVar_AirAccelerate;
ConVar g_ConVar_EnableBunnyhopping;

ConVar g_ConVar_Auto_AirAccelerate;
ConVar g_ConVar_EZHop;
ConVar g_ConVar_Weapon;

bool g_bWantsAuto[INF_MAXPLAYERS];

int g_Offset_hMyWeapons;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Mode - Auto",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    if ( (g_Offset_hMyWeapons = FindSendPropInfo( "CCSPlayer", "m_hMyWeapons" )) == -1 )
    {
        SetFailState( INF_CON_PRE..."Couldn't find offset for m_hMyWeapons!" );
    }
    
    
    if ( (g_ConVar_AirAccelerate = FindConVar( "sv_airaccelerate" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_airaccelerate!" );
    }
    
    if ( (g_ConVar_EnableBunnyhopping = FindConVar( "sv_enablebunnyhopping" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_enablebunnyhopping!" );
    }
    
    
    // EVENTS
    HookEvent( "player_jump", E_PlayerJump, EventHookMode_Post );
    HookEvent( "player_hurt", E_PlayerHurt, EventHookMode_Post );
    HookEvent( "player_spawn", E_PlayerSpawn );
    
    // CONVARS
    g_ConVar_Auto_AirAccelerate = CreateConVar( "influx_auto_airaccelerate", "1000", "", FCVAR_NOTIFY );
    g_ConVar_Auto_AirAccelerate.AddChangeHook( E_CvarChange_Auto_AA );
    
    g_ConVar_EZHop = CreateConVar( "influx_auto_ezhop", "1", "Does this mode have EZ-Hop?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_Weapon = CreateConVar( "influx_auto_weapon", "none", "What weapon do we give the player. (to set max speed to 260, etc.) | none = remove all weapons.", FCVAR_NOTIFY );
    
    AutoExecConfig( true, "mode_auto", "influx" );
    
    
    // CMDS
    RegConsoleCmd( "sm_auto", Cmd_Mode_Auto, INF_NAME..." - Change your mode to autobhop." );
    RegConsoleCmd( "sm_autobhop", Cmd_Mode_Auto, "" );
    RegConsoleCmd( "sm_abhop", Cmd_Mode_Auto, "" );
    RegConsoleCmd( "sm_ahop", Cmd_Mode_Auto, "" );
    RegConsoleCmd( "sm_a", Cmd_Mode_Auto, "" );
    
    RegConsoleCmd( "sm_toggleauto", Cmd_ToggleAuto, "" );
}

public void OnClientPutInServer( int client )
{
    g_bWantsAuto[client] = true;
}

public void OnClientDisconnect( int client )
{
    UnhookThinks( client );
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "auto", false )
    //||  StrEqual( szArg, "a", false )
    ||  StrEqual( szArg, "autobhop", false )
    ||  StrEqual( szArg, "auto-bhop", false )
    ||  StrEqual( szArg, "autobunnyhop", false ) )
    {
        value = MODE_AUTO;
        type = SEARCH_MODE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public void Influx_OnRequestModes()
{
    if ( !Influx_AddMode( MODE_AUTO, "Autobhop", "AUTO", 260.0 ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add mode! (%i)", MODE_AUTO );
    }
}

public Action Influx_OnClientModeChange( int client, int mode, int lastmode )
{
    if ( mode == MODE_AUTO )
    {
        if ( !Inf_SDKHook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client ) )
        {
            return Plugin_Handled;
        }
        
        if ( IsPlayerAlive( client ) )
            CheckWeapon( client );
        
        Inf_SendConVarValueFloat( client, g_ConVar_AirAccelerate, g_ConVar_Auto_AirAccelerate.FloatValue );
        Inf_SendConVarValueBool( client, g_ConVar_EnableBunnyhopping, true );
    }
    else if ( lastmode == MODE_AUTO )
    {
        UnhookThinks( client );
    }
    
    return Plugin_Continue;
}

stock void UnhookThinks( int client )
{
    SDKUnhook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client );
}

public void E_CvarChange_Auto_AA( ConVar convar, const char[] oldval, const char[] newval )
{
    g_flAirAccelerate = convar.FloatValue;
}

public void E_PlayerJump( Event event, const char[] szEvent, bool dontBroadcast )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( !client ) return;
    
    if ( Influx_GetClientMode( client ) != MODE_AUTO ) return;
    
    
    if ( g_ConVar_EZHop.BoolValue )
    {
        SetEntPropFloat( client, Prop_Send, "m_flStamina", 0.0 );
    }
}

public void E_PlayerHurt( Event event, const char[] szEvent, bool dontBroadcast )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( !client ) return;
    
    if ( Influx_GetClientMode( client ) != MODE_AUTO ) return;
    
    
    if ( g_ConVar_EZHop.BoolValue )
    {
        SetEntPropFloat( client, Prop_Send, "m_flVelocityModifier", 1.0 );
    }
}

public void E_PlayerSpawn( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( !client ) return;
    
    if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    
    if ( Influx_GetClientMode( client ) == MODE_AUTO )
    {
        RequestFrame( E_PlayerSpawn_Delay, GetClientUserId( client ) );
    }
}

public void E_PlayerSpawn_Delay( int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    if ( !IsPlayerAlive( client ) ) return;
    
    CheckWeapon( client );
}

public void E_PreThinkPost_Client( int client )
{
#if defined DEBUG_THINK
    PrintToServer( INF_DEBUG_PRE..."PreThinkPost - Auto (aa: %.0f)", g_flAirAccelerate );
#endif
    
    g_ConVar_AirAccelerate.FloatValue = g_flAirAccelerate;
    g_ConVar_EnableBunnyhopping.BoolValue = true;
}

public Action OnPlayerRunCmd( int client )
{
    if (IsPlayerAlive( client )
    &&  Influx_GetClientMode( client ) == MODE_AUTO
    &&  g_bWantsAuto[client]
    &&  GetEntityMoveType( client ) == MOVETYPE_WALK // Not on ladder
    &&  GetEntityWaterLevel( client ) <= 1 ) // Not submerged (when holding jump will keep you on the surface)
    {
        // This method allows other plugins to know whether player is holding the jump key or not.
        SetEntProp( client, Prop_Data, "m_nOldButtons", GetEntProp( client, Prop_Data, "m_nOldButtons" ) & ~IN_JUMP );
    }
    
    return Plugin_Continue;
}

public Action Cmd_Mode_Auto( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientMode( client, MODE_AUTO );
    
    return Plugin_Handled;
}

public Action Cmd_ToggleAuto( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    g_bWantsAuto[client] = !g_bWantsAuto[client];
    
    return Plugin_Handled;
}

stock void CheckWeapon( int client )
{
    int ent;
    
    decl String:wep[32];
    g_ConVar_Weapon.GetString( wep, sizeof( wep ) );
    
    if ( StrContains( wep, "weapon_" ) == 0 )
    {
        bool bFound = false;
        
        decl String:wep2[32];
        for ( int i = 0; i < 3; i++ )
        {
            if ( (ent = GetPlayerWeaponSlot( client, i )) != -1 )
            {
                if ( !GetEntityClassname( ent, wep2, sizeof( wep2 ) ) )
                    continue;
                
                if ( StrEqual( wep[7], wep2[7], false ) )
                {
                    bFound = true;
                    SetEntPropEnt( client, Prop_Send, "m_hActiveWeapon", ent );
                }
            }
        }
        
        if ( !bFound )
        {
            GivePlayerItem( client, wep );
        }
    }
    else
    {
        for ( int i = 0; i < 128; i += 4 )
        {
            if ( (ent = GetEntDataEnt2( client, g_Offset_hMyWeapons + i )) > 0 )
            {
                RemovePlayerItem( client, ent );
            }
        }
    }
}