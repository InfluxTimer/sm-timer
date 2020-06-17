#include <sourcemod>
#include <sdktools_hooks>
#include <sdkhooks>
#include <cstrike>

#include <influx/core>

#include <msharedutil/ents>


//#define DEBUG_THINK


float g_flAirAccelerate;


bool g_bWantsAuto[INF_MAXPLAYERS];


// CONVARS
ConVar g_ConVar_AirAccelerate;
#if !defined PRE_ORANGEBOX
ConVar g_ConVar_EnableBunnyhopping;
#endif

ConVar g_ConVar_Auto_AirAccelerate;
ConVar g_ConVar_EZHop;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Mode - Auto",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    if ( GetEngineVersion() != Engine_CSS )
    {
        FormatEx( szError, error_len, "This plugin is for CSS only. You can safely remove this plugin file." );
        return APLRes_SilentFailure;
    }
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    if ( (g_ConVar_AirAccelerate = FindConVar( "sv_airaccelerate" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_airaccelerate!" );
    }
    
#if !defined PRE_ORANGEBOX
    if ( (g_ConVar_EnableBunnyhopping = FindConVar( "sv_enablebunnyhopping" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_enablebunnyhopping!" );
    }
#endif

    
    // EVENTS
    HookEvent( "player_jump", E_PlayerJump, EventHookMode_Post );
    HookEvent( "player_hurt", E_PlayerHurt, EventHookMode_Post );
    
    // CONVARS
    g_ConVar_Auto_AirAccelerate = CreateConVar( "influx_auto_airaccelerate", "1000", "", FCVAR_NOTIFY );
    g_ConVar_Auto_AirAccelerate.AddChangeHook( E_CvarChange_Auto_AA );
    
    g_flAirAccelerate = g_ConVar_Auto_AirAccelerate.FloatValue;
    
    
    g_ConVar_EZHop = CreateConVar( "influx_auto_ezhop", "1", "Does this mode have EZ-Hop?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    AutoExecConfig( true, "mode_auto_css", "influx" );
    
    
    // CMDS
    RegConsoleCmd( "sm_auto", Cmd_Mode_Auto, INF_NAME..." - Change your mode to autobhop." );
    RegConsoleCmd( "sm_autobhop", Cmd_Mode_Auto, "" );
    RegConsoleCmd( "sm_abhop", Cmd_Mode_Auto, "" );
    RegConsoleCmd( "sm_ahop", Cmd_Mode_Auto, "" );
    RegConsoleCmd( "sm_a", Cmd_Mode_Auto, "" );
    
    RegConsoleCmd( "sm_toggleauto", Cmd_ToggleAuto, "" );
}

public void OnAllPluginsLoaded()
{
    AddMode();
}

public void OnPluginEnd()
{
    Influx_RemoveMode( MODE_AUTO );
}

public void OnClientPutInServer( int client )
{
    g_bWantsAuto[client] = true;
}

public void OnClientDisconnect( int client )
{
    UnhookThinks( client );
}

public void Influx_OnRequestModes()
{
    AddMode();
}

stock void AddMode()
{
    if ( !Influx_AddMode( MODE_AUTO, "Autobhop", "Auto", "auto", 260.0 ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add mode! (%i)", MODE_AUTO );
    }
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if (StrEqual( szArg, "auto", false )
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

public Action Influx_OnClientModeChange( int client, int mode, int lastmode )
{
    if ( mode == MODE_AUTO )
    {
        UnhookThinks( client );
        
        
        if ( !Inf_SDKHook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client ) )
        {
            return Plugin_Handled;
        }
        
        
        Inf_SendConVarValueFloat( client, g_ConVar_AirAccelerate, g_ConVar_Auto_AirAccelerate.FloatValue );
#if !defined PRE_ORANGEBOX
        Inf_SendConVarValueBool( client, g_ConVar_EnableBunnyhopping, true );
#endif
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
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    if ( Influx_GetClientMode( client ) != MODE_AUTO ) return;
    
    
    if ( g_ConVar_EZHop.BoolValue )
    {
        SetEntPropFloat( client, Prop_Send, "m_flStamina", 0.0 );
    }
}

public void E_PlayerHurt( Event event, const char[] szEvent, bool dontBroadcast )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    if ( Influx_GetClientMode( client ) != MODE_AUTO ) return;
    
    
    if ( g_ConVar_EZHop.BoolValue )
    {
        SetEntPropFloat( client, Prop_Send, "m_flVelocityModifier", 1.0 );
    }
}

public void E_PreThinkPost_Client( int client )
{
#if defined DEBUG_THINK
    PrintToServer( INF_DEBUG_PRE..."PreThinkPost - Auto (aa: %.0f)", g_flAirAccelerate );
#endif
    
    if ( Influx_GetClientMode( client ) != MODE_AUTO )
    {
        RequestFrame( UnhookThinksCb, GetClientUserId( client ) );
        return;
    }
    

    g_ConVar_AirAccelerate.FloatValue = g_flAirAccelerate;
    
#if !defined PRE_ORANGEBOX
    g_ConVar_EnableBunnyhopping.BoolValue = true;
#endif
}

public Action OnPlayerRunCmd( int client, int &buttons )
{
    if (IsPlayerAlive( client )
    &&  buttons & IN_JUMP
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

public void UnhookThinksCb( int userid ) // Can't unhook inside hook
{
    int client = GetClientOfUserId( userid );
    if ( client <= 0 || !IsClientInGame( client ) )
        return;


    UnhookThinks( client );
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