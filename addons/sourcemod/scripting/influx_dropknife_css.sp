#include <sourcemod>

#include <influx/core>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Drop Knife",
    description = "Allows players to drop their knife.",
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
    AddCommandListener( Lstnr_Drop, "drop" );
}

public Action Lstnr_Drop( int client, const char[] command, int argc )
{
    if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
    
    
    int wep = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" )
    
    if ( wep > 0 )
    {
        // weapon_knife
        decl String:sz[13];
        GetEntityClassname( wep, sz, sizeof( sz ) );
        
        
        if ( StrEqual( sz[7], "knife" ) )
        {
            RemovePlayerItem( client, wep );
        }
    }
    
    return Plugin_Continue;
}