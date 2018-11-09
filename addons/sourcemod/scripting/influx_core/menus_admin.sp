
public Action Cmd_Admin_RunMenu( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserModifyRun( client ) ) return Plugin_Handled;
    
    
    int len = g_hRuns.Length;
    
    Menu menu = new Menu( Hndlr_RunMenu );
    menu.SetTitle( "Run Menu\n " );
    
    menu.AddItem( "-1", "Save Runs\n ", len ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    menu.AddItem( "-2", "Run deletion menu", len ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    menu.AddItem( "0", "Record deletion menu\n " );
    
    
    char szInfo[8];
    char szDisplay[MAX_RUN_NAME + 16];
    int runid;
    
    for ( int i = 0; i < len; i++ )
    {
        runid = GetRunIdByIndex( i );
        
        GetRunNameByIndex( i, szDisplay, sizeof( szDisplay ) );
        Format( szDisplay, sizeof( szDisplay ), "%s (%i)", szDisplay, runid );
        
        FormatEx( szInfo, sizeof( szInfo ), "%i", runid );
        
        menu.AddItem( szInfo, szDisplay );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_Admin_RunSettings( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserModifyRun( client ) ) return Plugin_Handled;
    
    
    int runid = -1;
    if ( args )
    {
        char szArg[8];
        GetCmdArgString( szArg, sizeof( szArg ) );
        
        runid = StringToInt( szArg );
    }
    else
    {
        runid = g_iRunId[client];
    }
    
    
    int index = FindRunById( runid );
    if ( index == -1 )
    {
        Influx_PrintToChat( _, client, "You don't have run to edit!" );
        return Plugin_Handled;
    }
    
    
    int flags;
    int len;
    
    decl data[RUNRES_SIZE];
    
    decl String:szDisplay[92];
    decl String:szInfo[32];
    
    decl String:szTemp[64];
    
    decl String:szRun[MAX_RUN_NAME];
    GetRunNameByIndex( index, szRun, sizeof( szRun ) );
    
    
    Menu menu = new Menu( Hndlr_RunSettings );
    menu.SetTitle( "Run Settings: %s\n ", szRun );
    
    float pos[3];
    GetRunTelePos( index, pos );
    
    FormatEx( szInfo, sizeof( szInfo ), "%i_a_0", runid );
    FormatEx( szDisplay, sizeof( szDisplay ), "Set teleport position and angle\nPos: (%.1f, %.1f, %.1f) | Yaw: %.1f\n ",
        pos[0],
        pos[1],
        pos[2],
        GetRunTeleYaw( index ) );
    
    menu.AddItem( szInfo, szDisplay );
    
    
    // Result settings...
    flags = g_hRuns.Get( index, RUN_RESFLAGS );
    len = g_hRunResFlags.Length;
    for ( int i = 0; i < len; i++ )
    {
        g_hRunResFlags.GetArray( i, data );
        
        int resflag = data[RUNRES_FLAG];
        
        FormatEx( szDisplay, sizeof( szDisplay ), "%s: %s",
            data[RUNRES_NAME],
            ( flags & resflag ) ? "ON" : "OFF" );
        
        FormatEx( szInfo, sizeof( szInfo ), "%i_c_%i", runid, resflag );
        
        menu.AddItem( szInfo, szDisplay );
    }
    
    // Mode settings
    flags = g_hRuns.Get( index, RUN_MODEFLAGS );
    len = g_hModes.Length;
    for ( int i = 0; i < len; i++ )
    {
        int mode = g_hModes.Get( i, MODE_ID );
        
        GetModeNameByIndex( i, szTemp, sizeof( szTemp ) );
        
        FormatEx( szDisplay, sizeof( szDisplay ), "%s: %s",
            szTemp,
            ( flags & (1 << mode) ) ? "BLOCKED" : "ALLOWED" );
        
        FormatEx( szInfo, sizeof( szInfo ), "%i_d_%i", runid, mode );
        
        menu.AddItem( szInfo, szDisplay );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_Admin_DeleteRunMenu( int client, int args )
{
    if ( !CanUserRemoveRecords( client ) ) return Plugin_Handled;
    if ( !client ) return Plugin_Handled;
    
    
    int len = g_hRuns.Length;
    
    Menu menu = new Menu( Hndlr_DeleteRunMenu );
    menu.SetTitle( "Run Deletion Menu\n " );
    
    char szInfo[8];
    char szDisplay[MAX_RUN_NAME + 16];
    int runid;
    
    for ( int i = 0; i < len; i++ )
    {
        runid = GetRunIdByIndex( i );
        
        GetRunNameByIndex( i, szDisplay, sizeof( szDisplay ) );
        Format( szDisplay, sizeof( szDisplay ), "%s (%i)", szDisplay, runid );
        
        FormatEx( szInfo, sizeof( szInfo ), "%i", runid );
        
        menu.AddItem( szInfo, szDisplay );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_Admin_DeleteRecords( int client, int args )
{
    if ( !CanUserRemoveRecords( client ) ) return Plugin_Handled;
    if ( !client ) return Plugin_Handled;
    
    
    DB_PrintDeleteRecords( client, g_iCurMapId );
    
    return Plugin_Handled;
}
