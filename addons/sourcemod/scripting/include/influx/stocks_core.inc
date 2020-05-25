#if defined _influx_stocks_core_included
    #endinput
#endif
#define _influx_stocks_core_included


#include <cstrike>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>

#tryinclude <influx/autoversion>


#define INF_NAME                "Influx"
#define INF_AUTHOR              "Mehis"
#define INF_URL                 "https://influxtimer.com/"
#if !defined INF_VERSION
#define INF_VERSION             "manual"
#endif

#define INF_MAXPLAYERS          MAXPLAYERS + 1


// If you ever want to compile for pre-orangebox CSS versions.
// Also remember to change Engine_CSS in halflife.inc to 2.
//#define PRE_ORANGEBOX


// HACK: Pass these if you don't know the teleport pos / yaw.
#define INVALID_TELEAXIS    -1.0
#define INVALID_TELEPOS     view_as<float>( { INVALID_TELEAXIS, INVALID_TELEAXIS, INVALID_TELEAXIS } )
#define INVALID_TELEANG     -181.0

stock bool Inf_IsValidTelePos( const float pos[3] )
{
    return pos[0] != INVALID_TELEAXIS || pos[1] != INVALID_TELEAXIS || pos[2] != INVALID_TELEAXIS;
}

stock bool Inf_IsValidTeleAngle( const float yaw )
{
    return yaw != INVALID_TELEANG;
}

stock void Inf_FormatSeconds( float secs, char[] out, int len, const char[] secform = "%05.2f" )
{
    // "00:00.00"
    
#define _SECS2MINS(%0)  ( %0 * ( 1.0 / 60.0 ) )
    
    int mins = RoundToFloor( _SECS2MINS( secs ) );
    int printmins = mins;
    
    
    decl String:format[16];
    
    
    decl String:hrs[4]; // 00:
    hrs[0] = '\0';
    
    if ( mins >= 60 )
    {
        int h = RoundToFloor( _SECS2MINS( mins ) );
        
        FormatEx( hrs, sizeof( hrs ), "%02i:", h );
        
        printmins = mins - h * 60;
    }
    
    
    FormatEx( format, sizeof( format ), "%s%%02i:%s", hrs, secform ); // 00:%02i:%05.2f
    
    FormatEx( out, len, format,
        printmins,
        secs - mins * 60.0 );
}

stock void Inf_DecimalFormat( int numdecimals, char[] sz, int len )
{
    if ( numdecimals < 0 ) numdecimals = 0;
    
    int numzeros = 2; // Add base of 2
    if ( numdecimals > 0 ) numzeros += numdecimals + 1; // +1 is the dot
    
    FormatEx( sz, len, "%%0%i.%if", numzeros, numdecimals );
}

stock float Inf_GetTimeDif( float time, float compare_time, int &c )
{
    decl Float:dif;
    
    if ( time > compare_time )
    {
        dif = time - compare_time;
        c = '+';
    }
    else
    {
        dif = compare_time - time;
        c = '-';
    }
    
    return dif;
}

stock float Inf_SnapTo( float f, int num = 15 )
{
    int i = RoundFloat( f );
    
    int res = i - ( i % num );
    
    
    int dif = i - res;
    if ( dif >= (num / 2) ) res += num;
    else if ( dif <= (-num / 2) ) res -= num;
    
    return float( res );
}

stock void Inf_TelePosFromMinsMaxs( const float mins[3], const float maxs[3], float out[3] )
{
    // Trace down to get a valid player teleport destination.
    float vec[3], end[3];
    vec[0] = mins[0] + ( maxs[0] - mins[0] ) * 0.5;
    vec[1] = mins[1] + ( maxs[1] - mins[1] ) * 0.5;
    vec[2] = maxs[2] - 2.0;
    
    end = vec;
    end[2] = mins[2];
    
    TR_TraceHull( vec, end, PLYHULL_MINS, PLYHULL_MAXS_NOZ, MASK_SOLID );
    TR_GetEndPosition( end );
    
    vec[2] = end[2] + 2.0;
    
    out = vec;
}

stock bool Inf_FindTelePos( const float mins[3], const float maxs[3], float out[3], float &yaw_out )
{
    float pos[3], ang[3];
    int ent;
    
    static const char szClasses[][] = {
        "info_teleport_destination",
        "info_player_counterterrorist",
        "info_player_terrorist",
        "info_target" // Try info_targets last. Yes, some maps actually use it.
    };
    
    for ( int i = 0; i < sizeof( szClasses ); i++ )
    {
        ent = -1;
        while ( (ent = FindEntityByClassname( ent, szClasses[i] )) != -1 )
        {
            GetEntityOrigin( ent, pos );
            
            if ( IsInsideBounds( pos, mins, maxs ) )
            {
                GetEntPropVector( ent, Prop_Data, "m_angRotation", ang );
                
                out = pos;
                yaw_out = ang[1];
                
                return true;
            }
        }
    }
    
    return false;
}

stock float Inf_MinsMaxsToYaw( const float start_mins[3], const float start_maxs[3], const float target_mins[3], const float target_maxs[3] )
{
    float dir[2];
    for ( int j = 0; j < 2; j++ )
    {
        dir[j] = (target_mins[j] + ( target_maxs[j] - target_mins[j] ) * 0.5) - (start_mins[j] + ( start_maxs[j] - start_mins[j] ) * 0.5);
    }
    
    return RadToDeg( ArcTangent2( dir[1], dir[0] ) );
}

// Returns CS_TEAM_NONE if no available spawns are available.
stock int Inf_GetPreferredTeam( int &nOutSpawnsPref, int &nOutSpawnsOther, bool bBalance = false, int iPreferredTeam = CS_TEAM_CT )
{
    static char szPrefSpawn[32];
    static char szOtherSpawn[32];
    
    int iOtherTeam = CS_TEAM_NONE;
    
    if ( iPreferredTeam == CS_TEAM_CT )
    {
        iOtherTeam = CS_TEAM_T;
        
        strcopy( szPrefSpawn, sizeof( szPrefSpawn ), "info_player_counterterrorist" );
        strcopy( szOtherSpawn, sizeof( szOtherSpawn ), "info_player_terrorist" );
    }
    else
    {
        iOtherTeam = CS_TEAM_CT;
        
        strcopy( szPrefSpawn, sizeof( szPrefSpawn ), "info_player_terrorist" );
        strcopy( szOtherSpawn, sizeof( szOtherSpawn ), "info_player_counterterrorist" );
    }
    
    
    int nSpawnsPreferred = 0;
    int nSpawnsOthers = 0;
    int ent;
    
    ent = -1;
    while ( (ent = FindEntityByClassname( ent, szPrefSpawn )) != -1 ) nSpawnsPreferred++;
    ent = -1;
    while ( (ent = FindEntityByClassname( ent, szOtherSpawn )) != -1 ) nSpawnsOthers++;
    
    
    nOutSpawnsPref = nSpawnsPreferred;
    nOutSpawnsOther = nSpawnsOthers;
    
    int nPrefCount = GetTeamClientCount( iPreferredTeam );
    int nOtherCount = GetTeamClientCount( iOtherTeam );
    
    bool bEnoughPrefSpawns = ( nPrefCount < nSpawnsPreferred );
    bool bEnoughOtherSpawns = ( nOtherCount < nSpawnsOthers );
    
    
    
    // Balance the teams out if we have enough spawn points.
    if ( bBalance )
    {
        if ( nPrefCount <= nOtherCount && bEnoughPrefSpawns )
        {
            return iPreferredTeam;
        }
        else if ( nOtherCount <= nPrefCount && bEnoughOtherSpawns )
        {
            return iOtherTeam;
        }
    }
    
    
    // Just use the preferred team first.
    if ( bEnoughPrefSpawns )
    {
        return iPreferredTeam;
    }
    else if ( bEnoughOtherSpawns )
    {
        return iOtherTeam;
    }
    else // Our spawns are full!
    {
        // Check if there are any bots to take over.
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) && GetClientTeam( i ) > CS_TEAM_SPECTATOR && IsFakeClient( i ) )
            {
                return GetClientTeam( i );
            }
        }
    }
    
    
    return CS_TEAM_NONE;
}

stock bool Inf_CanClientUseAdminFlags( int client, int flags )
{
    // No flags, no problem.
    if ( flags == 0 ) return true;


    AdminId id = GetUserAdmin( client );
    if ( id == INVALID_ADMIN_ID )
    {
        return false;
    }


    return (flags & id.GetFlags( Access_Effective )) == flags;
}

// Delete the menu handle if ending, return if cancelling.
#define MENU_HANDLE(%0,%1)       if ( %1 == MenuAction_End ) { delete %0; return 0; } else if ( %1 == MenuAction_Cancel ) { return 0; }
