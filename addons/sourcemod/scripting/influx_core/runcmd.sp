// To call style check.
public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3] )
{
    if ( !IsPlayerAlive( client ) ) return;
    
    if ( IsFakeClient( client ) ) return;
    
    if ( g_iRunState[client] != STATE_RUNNING ) return;
    
    if ( g_iStyleId[client] == STYLE_INVALID ) return;
    
    
    if ( GetEntityFlags( client ) & FL_ONGROUND )
    {
        if ( GetEngineTime() >= g_flNextStyleGroundCheck[client] )
        {
            return;
        }
    }
    else
    {
        g_flNextStyleGroundCheck[client] = GetEngineTime() + 0.05;
    }
    
    
    if ( GetEntityWaterLevel( client ) > 1 ) return;
    
    
    MoveType mv = GetEntityMoveType( client );
    if ( mv == MOVETYPE_NOCLIP ) return;
    
    if ( !g_ConVar_LadderFreestyle.BoolValue && mv == MOVETYPE_LADDER ) return;
    
    
    // Check freestyle zone.
    if ( g_bLib_Zones_Fs )
    {
        if ( Influx_CanClientStyleFreestyle( client ) ) return;
    }
    
    Call_StartForward( g_hForward_OnCheckClientStyle );
    Call_PushCell( client );
    Call_PushCell( g_iStyleId[client] );
    Call_PushArrayEx( vel, sizeof( vel ), SM_PARAM_COPYBACK );
    Call_Finish();
}