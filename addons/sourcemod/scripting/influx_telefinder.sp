#include <sourcemod>

#include <influx/core>

#include <msharedutil/ents>


int g_iLastEnt[INF_MAXPLAYERS];


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Teleport to info_teleport_destination",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegAdminCmd( "sm_teletodest", Cmd_Admin_TeleToDest, ADMFLAG_ROOT );
}

public void OnClientPutInServer( int client )
{
    g_iLastEnt[client] = -1;
}

public Action Cmd_Admin_TeleToDest( int client, int args )
{
    if ( args )
    {
        char szName[64];
        GetCmdArgString( szName, sizeof( szName ) );

        int ent = FindEntityByTargetname( szName );
        if ( ent == -1 )
        {
            Inf_ReplyToClient( client, "Couldn't find influx_teleport_destination with name '%s'!", szName );
            return Plugin_Handled;
        }


        TeleToEntity( client, ent );

        return Plugin_Handled;
    }
    

    int ent = FindEntityByClassname( g_iLastEnt[client], "info_teleport_destination" );

    // Reset back to start and try again.
    if ( ent == -1 )
    {
        g_iLastEnt[client] = -1;
        ent = FindEntityByClassname( -1, "info_teleport_destination" );
    }

    if ( ent == -1 )
    {
        Inf_ReplyToClient( client, "Map has no info_teleport_destinations!" );
        return Plugin_Handled;
    }


    TeleToEntity( client, ent );
    g_iLastEnt[client] = ent;
    

    return Plugin_Handled;
}

// client may be server console.
stock void TeleToEntity( int client, int ent )
{
    char szName[64];
    float pos[3], ang[3];

    GetEntityName( ent, szName, sizeof( szName ) );
    GetEntityOrigin( ent, pos );
    GetEntPropVector( ent, Prop_Data, "m_angRotation", ang );
    ang[2] = 0.0;

    if ( client )
    {
        Influx_SetClientState( client, STATE_NONE );

        TeleportEntity( client, pos, ang, NULL_VECTOR );


        Inf_ReplyToClient( client, "Teleporting to info_teleport_destination '%s' (%.1f, %.1f, %.1f)!",
            szName,
            pos[0],
            pos[1],
            pos[2] );
    }
    else
    {
        Inf_ReplyToClient( client, "Found info_teleport_destination '%s' (%.1f, %.1f, %.1f)!",
            szName,
            pos[0],
            pos[1],
            pos[2] );
    }
}

stock int FindEntityByTargetname( const char[] szName )
{
    char szCurName[64];
    int ent = -1;
    while ( (ent = FindEntityByClassname( ent, "info_teleport_destination" )) != -1 )
    {
        GetEntityName( ent, szCurName, sizeof( szCurName ) );

        if ( StrEqual( szCurName, szName, false ) )
        {
            return ent;
        }
    }

    return -1;
}
