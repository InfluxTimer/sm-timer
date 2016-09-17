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

stock Strafe_t GetStrafe( float yaw, float prevyaw )
{
    float delta = yaw - prevyaw;
    
    if ( delta == 0.0 ) return STRF_INVALID;
    
    
    if ( delta > 0.0 )
    {
        return ( yaw > 175.0 && prevyaw < -175.0 ) ? STRF_RIGHT : STRF_LEFT;
    }
    else
    {
        return ( yaw < -175.0 && prevyaw > 175.0 ) ? STRF_LEFT : STRF_RIGHT;
    }
}