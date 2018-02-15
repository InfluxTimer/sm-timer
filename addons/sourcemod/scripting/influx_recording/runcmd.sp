public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon )
{
    if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
    
    
    if ( !IsFakeClient( client ) )
    {
        g_iCurWep[client] = weapon;
        g_fCurButtons[client] = buttons;
        
        return Plugin_Continue;
    }
    
    if ( client != g_iReplayBot )
    {
        return Plugin_Continue;
    }
    
    
    /*if ( !IsPlayerAlive( client ) )
    {
        if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR )
        {
            ChangeClientTeam( client, CS_TEAM_CT );
            
        }
        
        CS_RespawnPlayer( client );
        
        return Plugin_Continue;
    }*/
    
    if ( g_hReplay == null ) return Plugin_Handled;
    
    int len = g_hReplay.Length;
    if ( !len ) return Plugin_Handled;
    
    
    if ( g_nCurRec[client] >= len )
    {
        FinishPlayback();
        
        return Plugin_Handled;
    }
    
    
    static int data[REC_SIZE];
    static float pos[3];
    
    
    if ( g_nCurRec[client] == PLAYBACK_START )
    {
        g_hReplay.GetArray( 0, data );
        
        CopyArray( data[REC_POS], pos, 3 );
        CopyArray( data[REC_ANG], angles, 2 );
        
        TeleportEntity( client, pos, angles, ORIGIN_VECTOR );
    }
    else if ( g_nCurRec[client] == PLAYBACK_END )
    {
        return Plugin_Handled;
    }
    else
    {
        buttons = 0;
        vel[0] = 0.0;
        vel[1] = 0.0;
        vel[2] = 0.0;
        static float temp[3];
        
        g_hReplay.GetArray( g_nCurRec[client]++, data );
        
        CopyArray( data[REC_POS], pos, 3 );
        CopyArray( data[REC_ANG], angles, 2 );
        
        GetClientAbsOrigin( client, temp );
        
        
        int flags = data[REC_FLAGS];
        
        if ( flags & RECFLAG_CROUCH )
        {
            pos[2] -= 16.0;
            //buttons |= IN_DUCK;
        }
        
        if ( g_ConVar_WeaponAttack.BoolValue )
        {
            if ( flags & RECFLAG_ATTACK ) buttons |= IN_ATTACK;
            if ( flags & RECFLAG_ATTACK2 ) buttons |= IN_ATTACK2;
        }
        
        if ( g_ConVar_WeaponSwitch.BoolValue )
        {
            int wep = 0;
            
            if ( flags & RECFLAG_WEP_SLOT1 )        wep = GetPlayerWeaponSlot( client, SLOT_PRIMARY );
            else if ( flags & RECFLAG_WEP_SLOT2 )   wep = GetPlayerWeaponSlot( client, SLOT_SECONDARY );
            else if ( flags & RECFLAG_WEP_SLOT3 )   wep = GetPlayerWeaponSlot( client, SLOT_MELEE );
            
            if ( wep > 0 )
            {
                weapon = wep;
            }
        }
        
        
        if ( GetVectorDistance( pos, temp, true ) < g_flTeleportDistSq )
        {
            for ( int i = 0; i < 3; i++ )
            {
                temp[i] = ( pos[i] - temp[i] ) * g_flTickrate;
            }
            
#if defined DEBUG_BOT_MOVEMENT
            float veclen = GetVectorLength( temp, false );
            
            if ( veclen > 3500.0 )
            {
                PrintToServer( INF_DEBUG_PRE..."Replay exceeded maximum velocity (%.1f)! Movetype: %i | Grav Mult: %.1f | EntFlags: %i",
                    veclen,
                    GetEntityMoveType( client ),
                    GetEntityGravity( client ),
                    GetEntityFlags( client ) );
            }
#endif
            
            TeleportEntity( client, NULL_VECTOR, angles, temp );
        }
        else
        {
            TeleportEntity( client, pos, angles, NULL_VECTOR );
        }
    }
    
    return Plugin_Continue;
}