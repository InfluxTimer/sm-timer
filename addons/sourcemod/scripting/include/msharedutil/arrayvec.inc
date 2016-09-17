#if defined _msharedutils_arrayvec_included
    #endinput
#endif
#define _msharedutils_arrayvec_included


#include <sourcemod>


#define ORIGIN_VECTOR                   view_as<float>( { 0, 0, 0 } )

#define PLYHULL_MINS                    view_as<float>( { -16.0, -16.0, 0.0 } )
#define PLYHULL_MAXS                    view_as<float>( { 16.0, 16.0, 72.0 } )
#define PLYHULL_MAXS_NOZ                view_as<float>( { 16.0, 16.0, 0.0 } )

#define VALID_ARRAY_INDEX(%0,%1)        ( %0 != null && %1 >= 0 && %1 < %0.Length )
#define VALID_ARRAY_INDEX_NUL(%0,%1)    ( %1 >= 0 && %1 < %0.Length )
#define VALID_ARRAY_INDEX_LEN(%0,%1)    ( %0 >= 0 && %0 < %1 )

// atan2(Cross product (X), Dot product (Y))
stock float GetVectorsAngle( const float vec1[3], const float vec2[3] )
{
    return ArcTangent2( vec1[0] * vec2[1] - vec1[1] * vec2[0],
                        vec1[0] * vec2[0] + vec1[1] * vec2[1] );
}

stock void CorrectMinsMaxs( float mins_out[3], float maxs_out[3] )
{
    float temp;
    
    if ( mins_out[0] > maxs_out[0] )
    {
        temp = mins_out[0];
        mins_out[0] = maxs_out[0];
        maxs_out[0] = temp;
    }
    
    if ( mins_out[1] > maxs_out[1] )
    {
        temp = mins_out[1];
        mins_out[1] = maxs_out[1];
        maxs_out[1] = temp;
    }
    
    if ( mins_out[2] > maxs_out[2] )
    {
        temp = mins_out[2];
        mins_out[2] = maxs_out[2];
        maxs_out[2] = temp;
    }
}

stock bool IsInsideBounds( const float pos[3], const float mins[3], const float maxs[3] )
{
    return ((mins[0] <= pos[0] <= maxs[0])
        &&  (mins[1] <= pos[1] <= maxs[1])
        &&  (mins[2] <= pos[2] <= maxs[2]));
}

stock void CopyArray( const any[] from, any[] to, int len = 1 )
{
    for ( int i = 0; i < len; i++ )
    {
        to[i] = from[i];
    }
}

stock void FillArray( any[] array, any data, int len = 1 )
{
    for ( int i = 0; i < len; i++ )
    {
        array[i] = data;
    }
}

stock int GetArrayLength_Safe( ArrayList &array )
{
    return ( array != null ) ? array.Length : -1;
}