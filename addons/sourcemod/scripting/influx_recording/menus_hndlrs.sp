public int Hndlr_Replay( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !IsValidReplayBot() ) return 0;
    
    if ( !CanChangeReplay( client ) ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    if ( szInfo[0] == 'z' )
    {
        if ( CanReplayOwn( client ) )
        {
            ReplayOwn( client );
            
            ObserveTarget( client, g_iReplayBot );
        }
        
        return 0;
    }
    
    char buffer[3][6];
    if ( ExplodeString( szInfo, "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return 0;
    }
    
    
    int runid = StringToInt( buffer[0] );
    int mode = StringToInt( buffer[1] );
    int style = StringToInt( buffer[2] ); 
    
    
    int irun = FindRunRecById( runid );
    if ( irun == -1 ) return 0;
    
    if ( !VALID_MODE( mode ) ) return 0;
    
    if ( !VALID_STYLE( style ) ) return 0;
    
    
    ArrayList rec = GetRunRec( irun, mode, style );
    
    if ( rec != null )
    {
        char szName[MAX_NAME_LENGTH];
        GetRunName( irun, mode, style, szName, sizeof( szName ) );
        
        StartPlayback( rec, runid, mode, style, GetRunTime( irun, mode, style ), szName, client );
    }
    
    return 0;
}