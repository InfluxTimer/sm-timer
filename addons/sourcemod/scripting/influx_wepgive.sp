#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include <influx/core>

#undef REQUIRE_PLUGIN
#include <influx/help>


enum
{
    SLOT_PRIMARY,
    SLOT_SECONDARY,
    SLOT_MELEE
};


float g_flLastAllowed[INF_MAXPLAYERS];


bool g_bIsCSGO;

int g_Offset_hMyWeapons;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Give Weapons",
    description = "Give or drop weapons.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    g_bIsCSGO = ( GetEngineVersion() == Engine_CSGO );
    
    
    if ( (g_Offset_hMyWeapons = FindSendPropInfo( "CCSPlayer", "m_hMyWeapons" )) == -1 )
    {
        SetFailState( INF_CON_PRE..."Couldn't find offset for m_hMyWeapons!" );
    }
    
    
    RegConsoleCmd( "sm_scout", Cmd_Scout );
    RegConsoleCmd( "sm_usp", Cmd_Usp );
    RegConsoleCmd( "sm_glock", Cmd_Glock );
    RegConsoleCmd( "sm_knife", Cmd_Knife );
    
    RegConsoleCmd( "sm_drop", Cmd_Drop );
    RegConsoleCmd( "sm_dropweapon", Cmd_Drop );
    RegConsoleCmd( "sm_removeweapon", Cmd_Drop );
    RegConsoleCmd( "sm_removeweapons", Cmd_Drop );
    
    if ( g_bIsCSGO )
    {
        RegConsoleCmd( "sm_hkp", Cmd_Hpk );
        RegConsoleCmd( "sm_hkp2000", Cmd_Hpk );
    }
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "drop", "Remove all weapons." );
}

public void OnClientPutInServer( int client )
{
    g_flLastAllowed[client] = 0.0;
}

public Action Cmd_Drop( int client, int args )
{
    if ( client && IsPlayerAlive( client ) )
    {
        if ( Inf_HandleCmdSpam( client, 1.0, g_flLastAllowed[client], true ) )
        {
            return Plugin_Handled;
        }
        
        
        int wep;
        for ( int i = 0; i < 128; i += 4 )
        {
            if ( (wep = GetEntDataEnt2( client, g_Offset_hMyWeapons + i )) > 0 )
            {
                RemovePlayerItem( client, wep );
            }
        }
    }
    
    return Plugin_Handled;
}

public Action Cmd_Scout( int client, int args )
{
    GiveWeapon( client, g_bIsCSGO ? "weapon_ssg08" : "weapon_scout", SLOT_PRIMARY );
    return Plugin_Handled;
}

public Action Cmd_Hpk( int client, int args )
{
    GiveWeapon( client, "weapon_hkp2000", SLOT_SECONDARY );
    return Plugin_Handled;
}

public Action Cmd_Usp( int client, int args )
{
    GiveWeapon( client, g_bIsCSGO ? "weapon_usp_silencer" : "weapon_usp", SLOT_SECONDARY );
    return Plugin_Handled;
}

public Action Cmd_Glock( int client, int args )
{
    GiveWeapon( client, "weapon_glock", SLOT_SECONDARY );
    return Plugin_Handled;
}

public Action Cmd_Knife( int client, int args )
{
    GiveWeapon( client, "weapon_knife", SLOT_MELEE );
    return Plugin_Handled;
}

stock void GiveWeapon( int client, const char[] wepname, int slot )
{
    if ( !client ) return;
    
    if ( !IsPlayerAlive( client ) ) return;
    
    if ( Inf_HandleCmdSpam( client, 1.0, g_flLastAllowed[client], true ) )
    {
        return;
    }
    
    
    int wep;
    
    if ( (wep = GetPlayerWeaponSlot( client, slot )) > 0 && IsValidEdict( wep ) )
    {
        RemovePlayerItem( client, wep );
    }
    
    
    GivePlayerItem( client, wepname );
    
    
    // Equipping the weapon will for some reason delete it.
    //if ( wep > 0 ) EquipPlayerWeapon( client, wep );
}