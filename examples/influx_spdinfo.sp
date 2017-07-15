#include <sourcemod>
#include <sdkhooks>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>


enum
{
    SPD_VEL[3] = 0,
    SPD_SPD,
    SPD_ONGROUND,
    
    SPD_SIZE
};


ArrayList g_hSpds[MAXPLAYERS + 1];


int g_fLastFlags[MAXPLAYERS + 1];
int g_nJumps[MAXPLAYERS + 1];
int g_nMaxJumps[MAXPLAYERS + 1];


public void OnPluginStart()
{
    RegAdminCmd( "sm_spdinfo", Cmd_SpdInfo, ADMFLAG_ROOT );
    RegAdminCmd( "sm_outputspdinfo", Cmd_SpdInfo_Output, ADMFLAG_ROOT );
}

public void OnClientPutInServer( int client )
{
    UnhookThinks( client );
}

public void OnClientDisconnect( int client )
{
    
}

public Action Cmd_SpdInfo_Output( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( g_hSpds[client] == null ) return Plugin_Handled;
    
    if ( g_hSpds[client].Length < 1 ) return Plugin_Handled;
    
    
    decl String:szFile[256];
    
    GetCmdArgString( szFile, sizeof( szFile ) );
    
    if ( szFile[0] == 0 )
    {
        strcopy( szFile, sizeof( szFile ), "spdoutput.txt" );
    }
    
    
    decl data[SPD_SIZE];
    
    
    File file = OpenFile( szFile, "w" );
    
    
    int len = g_hSpds[client].Length;
    for ( int i = 0; i < len; i++ )
    {
        g_hSpds[client].GetArray( i, data );
        
        file.WriteLine( "SPD: %07.3f | ON GROUND: %i | VEL: {%.1f, %.1f, %.1f}",
            data[SPD_SPD],
            data[SPD_ONGROUND],
            data[SPD_VEL + 0],
            data[SPD_VEL + 1],
            data[SPD_VEL + 2] );
    }
    
    file.Close();
    
    PrintToChat( client, "Wrote %i frames to file '%s'!", g_hSpds[client].Length, szFile );
    
    return Plugin_Handled;
}

public Action Cmd_SpdInfo( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    delete g_hSpds[client];
    
    g_hSpds[client] = new ArrayList( SPD_SIZE );
    
    
    g_nJumps[client] = 0;
    
    
    char sz[32];
    GetCmdArgString( sz, sizeof( sz ) );
    
    g_nMaxJumps[client] = StringToInt( sz );
    
    if ( g_nMaxJumps[client] <= 0 ) g_nMaxJumps[client] = 6;
    
    
    g_fLastFlags[client] = GetEntityFlags( client );
    
    
    UnhookThinks( client );
    
    SDKHook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
    
    
    PrintToChat( client, "Jump to start... (%i jumps)", g_nMaxJumps[client] );
    
    
    return Plugin_Handled;
}

public void E_PostThinkPost_Client( int client )
{
    int flags = GetEntityFlags( client );
    
    
    bool onground = ( flags & FL_ONGROUND ) ? true : false;
    
    bool lastonground = ( g_fLastFlags[client] & FL_ONGROUND ) ? true : false;
    
    
    if ( !onground && lastonground )
    {
        if ( !g_nJumps[client] )
        {
            PrintToChat( client, "Started recording..." );
        }
        
        ++g_nJumps[client];
    }
    
    
    if ( g_nJumps[client] )
    {
        static int data[SPD_SIZE];
        
        float vec[3];
        GetEntityAbsVelocity( client, vec );
        
        float spd = SquareRoot( vec[0] * vec[0] + vec[1] * vec[1] );
        
        
        CopyArray( vec, data[SPD_VEL], 3 );
        data[SPD_SPD] = view_as<int>( spd );
        data[SPD_ONGROUND] = onground;
        
        g_hSpds[client].PushArray( data );
    }
    
    
    if ( onground && !lastonground && g_nJumps[client] >= g_nMaxJumps[client] )
    {
        PrintToChat( client, "Done! (sm_outputspdinfo)" );
        
        UnhookThinks( client );
        return;
    }
    
    
    g_fLastFlags[client] = flags;
}

stock void UnhookThinks( int client )
{
    SDKUnhook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
}