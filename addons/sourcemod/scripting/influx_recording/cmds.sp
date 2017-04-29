public Action Cmd_Empty( int client, int args ) { return Plugin_Handled; }

public Action Cmd_MyReplay( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( !IsValidReplayBot() ) return Plugin_Handled;
    
    if ( !CanChangeReplay( client ) ) return Plugin_Handled;
    
    
    FinishRecording( client, false );
    
    
    if ( CanReplayOwn( client ) )
    {
        ReplayOwn( client );
        
        ObserveTarget( client, g_iReplayBot );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Debug_Replay( int client, int args )
{
    if ( client )
    {
        PrintToServer( "Observer target: %i", GetClientObserverTarget( client ) );
    }
    
    decl i, j, k;
    for ( i = 0; i < g_hRunRec.Length; i++ )
        for ( j = 0; j < MAX_MODES; j++ )
            for ( k = 0; k < MAX_STYLES; k++ )
                if ( GetRunRec( i, j, k ) != null )
                {
                    PrintToServer( INF_DEBUG_PRE..."[%i,%i,%i]: %x", i, j, k, GetRunRec( i, j, k ) );
                }
    
    return Plugin_Handled;
}