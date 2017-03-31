#if defined _influx_stocks_strf_included
    #endinput
#endif
#define _influx_stocks_strf_included

enum Strafe_t
{
    STRF_INVALID = 0,
    STRF_LEFT,
    STRF_RIGHT
};

stock Strafe_t GetStrafe( float yaw, float prevyaw, float grace = 5.0 )
{
    float delta = yaw - prevyaw;
    
    if ( delta == 0.0 ) return STRF_INVALID;
    
    
    float min = -180.0 + grace;
    float max = 180.0 - grace;
    
    
    if ( delta > 0.0 )
    {
        return ( yaw > max && prevyaw < min ) ? STRF_RIGHT : STRF_LEFT;
    }
    else
    {
        return ( yaw < min && prevyaw > max ) ? STRF_LEFT : STRF_RIGHT;
    }
}