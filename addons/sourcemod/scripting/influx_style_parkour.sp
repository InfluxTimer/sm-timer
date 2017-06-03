#include <sourcemod>
#include <sdktools>

#include <influx/core>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>


#define TRACEDIF            8.0

#define WALLJUMP_BOOST      500.0

#define BOOST               500.0


float g_flNextWallJump[INF_MAXPLAYERS];
float g_flNextBoost[INF_MAXPLAYERS];


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Style - Parkour",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_parkour", Cmd_Style_Parkour, "Change your style to parkour." );
}

public void OnAllPluginsLoaded()
{
    if ( !Influx_AddStyle( STYLE_PARKOUR, "Parkour", "Parkour", "parkour" ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add style!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveStyle( STYLE_PARKOUR );
}

public void Influx_OnRequestStyles()
{
    OnAllPluginsLoaded();
}

public void OnClientPutInServer( int client )
{
    g_flNextWallJump[client] = 0.0;
    g_flNextBoost[client] = 0.0;
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if ( StrEqual( szArg, "parkour", false ) )
    {
        value = STYLE_PARKOUR;
        type = SEARCH_STYLE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action OnPlayerRunCmd( int client, int &buttons )
{
    if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
    if ( Influx_GetClientStyle( client ) != STYLE_PARKOUR ) return Plugin_Continue;
    
    
    if ( buttons & IN_ATTACK2 && g_flNextWallJump[client] < GetEngineTime() )
    {
        decl Float:pos[3];
        decl Float:normal[3];
        
        GetClientAbsOrigin( client, pos );
        
        if ( FindWall( pos, normal ) )
        {
            decl Float:vel[3];
            GetEntityVelocity( client, vel );
            
            for ( int i = 0; i < 3; i++ )
            {
                vel[i] += normal[i] * WALLJUMP_BOOST;
            }
            
            if ( vel[2] < WALLJUMP_BOOST )
            {
                vel[2] = WALLJUMP_BOOST;
            }
            
            
            TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, vel );
            
            
            g_flNextWallJump[client] = GetEngineTime() + 0.5;
        }
    }
    
    if ( buttons & IN_ATTACK && g_flNextBoost[client] < GetEngineTime() )
    {
        decl Float:vec[3];
        GetClientEyeAngles( client, vec );
        
        GetAngleVectors( vec, vec, NULL_VECTOR, NULL_VECTOR );
        
        
        decl Float:vel[3];
        GetEntityVelocity( client, vel );
        
        for ( int i = 0; i < 3; i++ )
        {
            vel[i] += vec[i] * BOOST;
        }
        
        TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, vel );
        
        
        g_flNextBoost[client] = GetEngineTime() + 3.0;
    }
    
    return Plugin_Continue;
}

stock bool FindWall(  const float pos[3], float normal[3] )
{
    decl Float:end[3];
    
    
    end = pos; end[0] += TRACEDIF;
    if ( GetTraceNormal( pos, end, normal ) ) return true;
    
    end = pos; end[0] -= TRACEDIF;
    if ( GetTraceNormal( pos, end, normal ) ) return true;
    
    end = pos; end[1] += TRACEDIF;
    if ( GetTraceNormal( pos, end, normal ) ) return true;
    
    end = pos; end[1] -= TRACEDIF;
    if ( GetTraceNormal( pos, end, normal ) ) return true;
    
    end = pos; end[2] += TRACEDIF;
    if ( GetTraceNormal( pos, end, normal ) ) return true;
    
    end = pos; end[2] -= TRACEDIF;
    if ( GetTraceNormal( pos, end, normal ) ) return true;
    
    
    return false;
}

stock bool GetTraceNormal( const float pos[3], const float end[3], float normal[3] )
{
    TR_TraceHullFilter( pos, end, PLYHULL_MINS, PLYHULL_MAXS, MASK_PLAYERSOLID, TrcFltr_AnythingButThoseFilthyScrubs );
    
    if ( TR_GetFraction() != 1.0 )
    {
        TR_GetPlaneNormal( null, normal );
        return true;
    }
    
    return false;
}

public bool TrcFltr_AnythingButThoseFilthyScrubs( int ent, int mask, any data )
{
    return ( ent == 0 || ent > MaxClients );
}

public Action Cmd_Style_Parkour( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientStyle( client, STYLE_PARKOUR );
    
    return Plugin_Handled;
}