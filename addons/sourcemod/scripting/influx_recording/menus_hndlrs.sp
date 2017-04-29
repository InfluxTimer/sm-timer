public int Hndlr_Replay( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !IsValidReplayBot() ) return 0;
    
    if ( !CanChangeReplay( client ) ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    if ( szInfo[0] == 'z' )
    {
        FakeClientCommand( client, "sm_myreplay" );
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

public int Hndlr_DeleteRecording( Menu oldmenu, MenuAction action, int client, int index )
{
    MENU_HANDLE( oldmenu, action )
    
    
    if ( !CanUserDeleteRecordings( client ) ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
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
    
    
    decl String:szDisplay[128];
    decl String:szTime[16];
    decl String:szMode[MAX_MODE_NAME];
    decl String:szStyle[MAX_STYLE_NAME];
    
    
    Inf_FormatSeconds( GetRunTime( irun, mode, style ), szTime, sizeof( szTime ) );
    
    
    if ( Influx_ShouldModeDisplay( mode ) ) Influx_GetModeShortName( mode, szMode, sizeof( szMode ) );
    else szMode[0] = '\0';
    
    if ( Influx_ShouldStyleDisplay( style ) ) Influx_GetStyleShortName( style, szStyle, sizeof( szStyle ) );
    else szStyle[0] = '\0';
    
    
    FormatEx( szDisplay, sizeof( szDisplay ), "%s%s%s | %s",
        szStyle,
        ( szStyle[0] != '\0' ) ? " " : "",
        szMode,
        szTime );
    
    Menu menu = new Menu( Hndlr_DeleteRecording_Confirm );
    menu.SetTitle( "Are you sure you want to delete %s?\n ", szDisplay );
    
    menu.AddItem( szInfo, "Yes" );
    menu.AddItem( "", "No" );
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return 0;
}

public int Hndlr_DeleteRecording_Confirm( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( index != 0 ) return 0;
    
    
    if ( !CanUserDeleteRecordings( client ) ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
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
    
    
    if ( DeleteRecording( runid, mode, style ) )
    {
        decl String:szPath[PLATFORM_MAX_PATH];
        FormatRecordingPath( szPath, sizeof( szPath ), runid, mode, style );
        
        Influx_PrintToChat( _, client, "Successfully deleted '{MAINCLR1}...%s{CHATCLR}'!", szPath[16] );
        
        
        ArrayList rec = GetRunRec( irun, mode, style );
        
        if ( rec != null )
        {
            if ( g_hReplay == rec )
            {
                g_hReplay = null;
            }
            
            SetRunRec( irun, mode, style, null );
            
            delete rec;
        }
    }
    
    return 0;
}