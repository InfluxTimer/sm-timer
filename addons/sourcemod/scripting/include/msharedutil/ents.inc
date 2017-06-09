#if defined _msharedutil_ents_included
    #endinput
#endif
#define _msharedutil_ents_included


#include <sourcemod>


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
    SetEntPropEnt( client, Prop_Send, "m_hObserverTarget", ent );
}

stock void GetEntityName( int ent, char[] sz, int len )
{
    GetEntPropString( ent, Prop_Data, "m_iName", sz, len );
}

stock void SetEntityName( int ent, char[] sz )
{
    SetEntPropString( ent, Prop_Data, "m_iName", sz );
}

stock void SetEntityClassname( int ent, char[] sz )
{
	SetEntPropString( ent, Prop_Data, "m_iClassname", sz );
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

stock void GetEntityAbsVelocity( int ent, float out[3] )
{
    GetEntPropVector( ent, Prop_Data, "m_vecAbsVelocity", out );
}

stock void GetEntityBaseVelocity( int ent, float out[3] )
{
    GetEntPropVector( ent, Prop_Data, "m_vecBaseVelocity", out );
}

stock void GetEntityVelocity( int ent, float out[3] )
{
    GetEntPropVector( ent, Prop_Data, "m_vecVelocity", out );
}

stock void SetEntityBaseVelocity( int ent, const float vec[3] )
{
    SetEntPropVector( ent, Prop_Data, "m_vecBaseVelocity", vec );
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

stock int GetEntityCollisionGroup( int ent )
{
    return GetEntProp( ent, Prop_Data, "m_CollisionGroup" );
}

stock void SetEntityCollisionGroup( int ent, int group )
{
    SetEntProp( ent, Prop_Data, "m_CollisionGroup", group );
}
