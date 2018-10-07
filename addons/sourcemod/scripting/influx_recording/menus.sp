public Action Cmd_Replay( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Inf_HandleCmdSpam( client, 1.0, g_flLastReplayMenu[client], true ) )
    {
        return Plugin_Handled;
    }
    
    if ( !IsValidReplayBot() ) return Plugin_Handled;
    
    
    
    if ( !ObserveTarget( client, g_iReplayBot ) )
    {
        return Plugin_Handled;
    }
    
    
    decl runid, irun, mode, style;
    decl String:szTime[10];
    decl String:szRun[MAX_RUN_NAME];
    decl String:szMode[MAX_MODE_NAME];
    decl String:szStyle[MAX_STYLE_NAME];
    decl String:szInfo[32];
    decl String:szDisplay[64];
    ArrayList rec;
    
    
    Menu menu = new Menu( Hndlr_Replay );
    menu.SetTitle( "Replay Menu\n ", szRun );
    
    
    menu.AddItem( "z", "Own Replay\n ", CanReplayOwn( client ) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    int num = 0;

    int len = g_hRunRec.Length;
    for ( irun = 0; irun < len; irun++ )
    {
        runid = g_hRunRec.Get( irun, RUNREC_RUN_ID );
        
        Influx_GetRunName( runid, szRun, sizeof( szRun ) );

        for ( mode = 0; mode < MAX_MODES; mode++ )
        {
            if ( Influx_ShouldModeDisplay( mode ) ) Influx_GetModeShortName( mode, szMode, sizeof( szMode ) );
            else szMode[0] = '\0';
            
            for ( style = 0; style < MAX_STYLES; style++ )
                if ( (rec = GetRunRec( irun, mode, style )) != null )
                {
                    FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i",
                        runid,
                        mode,
                        style );
                    
                    
                    Inf_FormatSeconds( GetRunTime( irun, mode, style ), szTime, sizeof( szTime ) );
                    
                    
                    if ( Influx_ShouldStyleDisplay( style ) ) Influx_GetStyleShortName( style, szStyle, sizeof( szStyle ) );
                    else szStyle[0] = '\0';
                    
                    
                    FormatEx( szDisplay, sizeof( szDisplay ), "%s | %s | %s%s%s%s",
                        szRun,
                        szTime,
                        szStyle,
                        ( szStyle[0] != '\0' ) ? " " : "",
                        szMode,
                        ( rec == g_hReplay ) ? " (ACTIVE)" : "" );
                    
                    menu.AddItem( szInfo, szDisplay );
                    ++num;
                }
        }
    }
    
    // Only one recording exists. Go to it.
    if ( num == 1 )
    {
        if ( CanChangeReplay( client ) )
        {
            FindNewPlayback();
        }
        
        delete menu;
        return Plugin_Handled;
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_DeleteRecordings( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserDeleteRecordings( client ) ) return Plugin_Handled;
    
    
    
    decl runid, irun, mode, style;
    decl String:szTime[10];
    decl String:szRun[MAX_RUN_NAME];
    decl String:szMode[MAX_MODE_NAME];
    decl String:szStyle[MAX_STYLE_NAME];
    decl String:szInfo[32];
    decl String:szDisplay[64];
    ArrayList rec;
    int num = 0;
    
    
    Menu menu = new Menu( Hndlr_DeleteRecording );
    menu.SetTitle( "Recording Deletion Menu\n " );

    int len = g_hRunRec.Length;
    for ( irun = 0; irun < len; irun++ )
    {
        runid = g_hRunRec.Get( irun, RUNREC_RUN_ID );
        
        Influx_GetRunName( runid, szRun, sizeof( szRun ) );

        for ( mode = 0; mode < MAX_MODES; mode++ )
        {
            if ( Influx_ShouldModeDisplay( mode ) ) Influx_GetModeShortName( mode, szMode, sizeof( szMode ) );
            else szMode[0] = '\0';
            
            for ( style = 0; style < MAX_STYLES; style++ )
                if ( (rec = GetRunRec( irun, mode, style )) != null )
                {
                    FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i",
                        runid,
                        mode,
                        style );
                    
                    
                    Inf_FormatSeconds( GetRunTime( irun, mode, style ), szTime, sizeof( szTime ) );
                    
                    
                    if ( Influx_ShouldStyleDisplay( style ) ) Influx_GetStyleShortName( style, szStyle, sizeof( szStyle ) );
                    else szStyle[0] = '\0';
                    
                    
                    FormatEx( szDisplay, sizeof( szDisplay ), "%s | %s | %s%s%s%s",
                        szRun,
                        szTime,
                        szStyle,
                        ( szStyle[0] != '\0' ) ? " " : "",
                        szMode,
                        ( rec == g_hReplay ) ? " (ACTIVE)" : "" );
                    
                    menu.AddItem( szInfo, szDisplay );
                    
                    ++num;
                }
        }
    }
    
    if ( !num )
    {
        menu.AddItem( "", "No recordings exist! :(", ITEMDRAW_DISABLED );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}