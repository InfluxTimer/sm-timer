#include <sourcemod>
#include <sdkhooks>

#include <influx/core>
#include <influx/stocks_core>

#include <msharedutil/ents>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Weapon Drop",
    description = "Disable weapon dropping.",
    version = INF_VERSION
};

public void OnClientPutInServer( int client )
{
    Inf_SDKHook( client, SDKHook_WeaponDropPost, E_WeaponDropPost_Client );
}

public void OnClientDisconnect( int client )
{
    SDKUnhook( client, SDKHook_WeaponDropPost, E_WeaponDropPost_Client );
}

public void E_WeaponDropPost_Client( int client, int weapon )
{
    if ( weapon < 1 ) return;
    
    if ( !IsValidEntity( weapon ) ) return;
    
    
    if ( !KillEntity( weapon ) )
    {
        decl String:wep[32];
        GetEntityClassname( weapon, wep, sizeof( wep ) );
        
        LogError( INF_CON_PRE..."Couldn't delete weapon %s (%i)!", wep, weapon );
    }
}