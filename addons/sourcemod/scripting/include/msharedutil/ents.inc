#if defined _msharedutil_ents_included
    #endinput
#endif
#define _msharedutil_ents_included


#include <sourcemod>
#include <sdktools>


// MUST BE PRECACHED!
#define MAGIC_BRUSH_MODEL       "models/props/cs_office/vending_machine.mdl"

#define SF_CLIENTS              1
#define SF_NOBOTS               4096

#define OBS_MODE_IN_EYE         4
#define OBS_MODE_ROAMING        6

#define IS_ENT_PLAYER(%0)       ( %0 > 0 && %0 <= MaxClients )


stock int GetClientObserverMode( int client )
{
    return GetEntProp( client, Prop_Send, "m_iObserverMode" );
}

stock void SetClientObserverMode( int client, int mode )
{
    SetEntProp( client, Prop_Send, "m_iObserverMode", mode );
}

stock int GetClientObserverTarget( int client )
{
    return GetEntPropEnt( client, Prop_Send, "m_hObserverTarget" );
}

stock void SetClientObserverTarget( int client, int ent )
{
    SetEntProp( client, Prop_Send, "m_hObserverTarget", ent );
}

stock int GetEntityWaterLevel( int ent )
{
    return GetEntProp( ent, Prop_Data, "m_nWaterLevel" );
}

stock float GetEntitySpeedSquared( int ent )
{
    float vec[3];
    GetEntityVelocity( ent, vec );
    
    return ( vec[0] * vec[0] + vec[1] * vec[1] );
}

stock float GetEntitySpeed( int ent )
{
    return SquareRoot( GetEntitySpeedSquared( ent ) );
}

stock float GetEntityTrueSpeedSquared( int ent )
{
    float vec[3];
    GetEntityVelocity( ent, vec );
    
    return ( vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2] );
}

stock float GetEntityTrueSpeed( int ent )
{
    return SquareRoot( GetEntityTrueSpeedSquared( ent ) );
}

stock void GetEntityBaseVelocity( int ent, float out[3] )
{
    GetEntPropVector( ent, Prop_Data, "m_vecBaseVelocity", out );
}

stock void GetEntityVelocity( int ent, float out[3] )
{
    GetEntPropVector( ent, Prop_Data, "m_vecVelocity", out );
}

stock void SetEntityVelocity( int ent, const float vec[3] )
{
    SetEntPropVector( ent, Prop_Data, "m_vecVelocity", vec );
}

stock void GetEntityOrigin( int ent, float vec[3] )
{
    GetEntPropVector( ent, Prop_Data, "m_vecOrigin", vec );
}

stock bool KillEntity( int ent )
{
    return AcceptEntityInput( ent, "Kill" );
}

stock void GetEntityCollisionGroup( int ent )
{
    return GetEntProp( ent, Prop_Data, "m_CollisionGroup" );
}

stock void SetEntityCollisionGroup( int ent, int group )
{
    SetEntProp( ent, Prop_Data, "m_CollisionGroup", group );
}

// Clients only by default.
stock int CreateTrigger( const float vecMins[3], const float vecMaxs[3], int spawnflags = SF_CLIENTS | SF_NOBOTS )
{
    int ent = CreateEntityByName( "trigger_multiple" );
    
    if ( ent < 1 )
    {
        LogError( "Couldn't create trigger entity!" );
        return -1;
    }
    
    
    DispatchKeyValue( ent, "wait", "0" );
    
    char szSpawn[16];
    FormatEx( szSpawn, sizeof( szSpawn ), "%i", spawnflags );
    DispatchKeyValue( ent, "spawnflags", szSpawn ); 
    
    if ( !DispatchSpawn( ent ) )
    {
        LogError( "Couldn't spawn trigger entity!" );
        return -1;
    }
    
    float vecPos[3], vecNewMins[3], vecNewMaxs[3];
    
    ActivateEntity( ent );
    
    
    SetEntityModel( ent, MAGIC_BRUSH_MODEL );
    
    SetEntProp( ent, Prop_Send, "m_fEffects", 32 ); // EF_NODRAW
    
    
    vecNewMaxs[0] = ( vecMaxs[0] - vecMins[0] ) * 0.5;
    vecNewMaxs[1] = ( vecMaxs[1] - vecMins[1] ) * 0.5;
    vecNewMaxs[2] = ( vecMaxs[2] - vecMins[2] ) * 0.5;
    
    vecPos[0] = vecMins[0] + vecNewMaxs[0];
    vecPos[1] = vecMins[1] + vecNewMaxs[1];
    vecPos[2] = vecMins[2] + vecNewMaxs[2];
    
    
    TeleportEntity( ent, vecPos, NULL_VECTOR, NULL_VECTOR );
    
    
    vecNewMins[0] = -vecNewMaxs[0];
    vecNewMins[1] = -vecNewMaxs[1];
    vecNewMins[2] = -vecNewMaxs[2];
    
    SetEntPropVector( ent, Prop_Send, "m_vecMins", vecNewMins );
    SetEntPropVector( ent, Prop_Send, "m_vecMaxs", vecNewMaxs );
    SetEntProp( ent, Prop_Send, "m_nSolidType", 2 ); // Essential! Use bounding box instead of model's bsp(?) for input.
    
    return ent;
}