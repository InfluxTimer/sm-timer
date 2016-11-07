#if defined _influx_stocks_core_included
    #endinput
#endif
#define _influx_stocks_core_included


#include <msharedutil/arrayvec>
#include <msharedutil/ents>


#define INF_NAME                "Influx"
#define INF_AUTHOR              "Mehis"
#define INF_URL                 "http://influxtimer.com/"
// If a plugin doesn't have the same version number, it may need a recompile.
#define INF_VERSION             "1.0.4"


#define INF_MAXPLAYERS          MAXPLAYERS + 1


stock void Inf_FormatSeconds( float secs, char[] out, int len, const char[] secform = "%05.2f" )
{
    // "00:00.00"
    
#define SECS2MINS(%0)    ( %0 * ( 1.0 / 60.0 ) )
    
    int mins = RoundToFloor( SECS2MINS( secs ) );
    
    decl String:format[16];
    FormatEx( format, sizeof( format ), "%%02i:%s", secform ); // %02i:%05.2f
    
    FormatEx( out, len, format,
        mins,
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
    int i = RoundFloat( f ) + ( num / 2 );
    
    return float( i - ( i % num ) );
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
    
    int ent = -1;
    while ( (ent = FindEntityByClassname( ent, "info_teleport_destination" )) != -1 )
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

// Delete the menu handle if ending, return if cancelling.
#define MENU_HANDLE(%0,%1)       if ( %1 == MenuAction_End ) { delete %0; return 0; } else if ( %1 == MenuAction_Cancel ) { return 0; }