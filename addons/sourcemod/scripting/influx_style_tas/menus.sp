
public Action Cmd_TasMenu( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    decl String:szDisplay[32];
    
    
    Menu menu = new Menu( Hndlr_TasMenu );
    menu.SetTitle( "TAS Menu (!tas_menu)\n " );
    
    menu.AddItem( "c", ShouldContinue( client ) ? "Continue\n " : "Stop\n " );
    
    
    // Fast forward
    strcopy( szDisplay, sizeof( szDisplay ), ">>| Forward" );
    
    if ( g_flPlayback[client] > 0.0 )
    {
        Format( szDisplay, sizeof( szDisplay ), "%s (%.2fx)", szDisplay, g_flPlayback[client] );
    }
    
    menu.AddItem( "d", szDisplay );
    
    
    // Rewind
    strcopy( szDisplay, sizeof( szDisplay ), "<<| Rewind" );
    
    if ( g_flPlayback[client] < 0.0 )
    {
        Format( szDisplay, sizeof( szDisplay ), "%s (%.2fx)", szDisplay, -g_flPlayback[client] );
    }
    
    Format( szDisplay, sizeof( szDisplay ), "%s\n ", szDisplay );
    
    menu.AddItem( "e", szDisplay );
    
    if ( CanAdvanceFrame( client ) )
    {
        menu.AddItem( "g", "> Advance Frame" );
    }
    else
    {
        menu.AddItem( "a", "> Next Frame" );
    }
    
    menu.AddItem( "b", "< Previous Frame\n " );
    
    menu.AddItem( "h", "CP Menu" );
    menu.AddItem( "f", "Settings\n " );
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_TasCPMenu( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    bool bHasCP = ( g_hFrameCP[client] != null && g_hFrameCP[client].Length > 0 );
    
    int numcps = 0;
    
    
    Menu menu = new Menu( Hndlr_TasCPMenu );
    
    
    menu.AddItem( "a", ShouldContinue( client ) ? "Continue\n " : "Stop\n " );
    
    
    menu.AddItem( "b", "Add CP" );
    menu.AddItem( "c", "Last used", bHasCP ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    menu.AddItem( "d", "Last created\n ", bHasCP ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    
    menu.AddItem( "e", "Back to TAS menu" );
    menu.AddItem( "f", "Settings\n " );
    
    
    if ( bHasCP )
    {
        decl String:szDisplay[32];
        decl String:szInfo[32];
        
        int num;
        
        int endindex = g_iCurCP[client];
        
        for ( int i = g_iCurCP[client] - 1;; i-- )
        {
            if ( i < 0 )
            {
                i = MAX_FRMCP - 1;
            }
            
            
            num = g_hFrameCP[client].Get( i, FRMCP_NUM );
            
            if ( num > 0 )
            {
                FormatEx( szInfo, sizeof( szInfo ), "g%i", num );
                FormatEx( szDisplay, sizeof( szDisplay ), "CP %i (%i)", num, g_hFrameCP[client].Get( i, FRMCP_FRMINDEX ) + 1 );
                
                menu.AddItem( szInfo, szDisplay );
                
                ++numcps;
            }
            
            if ( i == endindex ) break;
        }
    }

    menu.SetTitle( "TAS CP Menu (!tas_cpmenu)\nCheckpoints: %i\n ", numcps );
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_Settings( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    decl String:szDisplay[32];
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "TAS Settings (!tas_settings)\n " );
    
    FormatEx( szDisplay, sizeof( szDisplay ), "Timescale: %.2fx", g_flTimescale[client] );
    menu.AddItem( "a", szDisplay, CanUserUseTimescale( client ) ? 0 : ITEMDRAW_DISABLED );
    
    
    switch ( g_iAutoStrafe[client] )
    {
        case AUTOSTRF_CONTROL : strcopy( szDisplay, sizeof( szDisplay ), "Easy Control" );
        case AUTOSTRF_MAXSPEED : strcopy( szDisplay, sizeof( szDisplay ), "Maximum Speed" );
        default : strcopy( szDisplay, sizeof( szDisplay ), "Off" );
    }
    
    Format( szDisplay, sizeof( szDisplay ), "Auto-strafe: %s", szDisplay );
    menu.AddItem( "b", szDisplay );
    
    
    switch ( g_iAimlock[client] )
    {
        case AIMLOCK_FAKEANG : strcopy( szDisplay, sizeof( szDisplay ), "Silent Angles" );
        case AIMLOCK_ANG : strcopy( szDisplay, sizeof( szDisplay ), "Real Angles" );
        default : strcopy( szDisplay, sizeof( szDisplay ), "Off" );
    }
    
    Format( szDisplay, sizeof( szDisplay ), "Pause Aimlock: %s\n ", szDisplay );
    menu.AddItem( "g", szDisplay );
    
    
    menu.AddItem( "c", "Display list of commands\n " );
    
    
    int itemdraw = CanUserLoadSaveTas( client ) ? 0 : ITEMDRAW_DISABLED;
    
    menu.AddItem( "e", "Load Run", itemdraw );
    menu.AddItem( "f", "Save Run\n ", itemdraw );
    
    menu.AddItem( "d", "Back to TAS menu\n " );
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_ListCmds( int client, int args )
{
    if ( !client ) return Plugin_Handled;
   
   
    Menu menu = new Menu( Hndlr_ListCmds );
    menu.SetTitle( "TAS Commands (!tas_listcmds)\n " );
    
    menu.AddItem( "a", "Back to TAS menu\n " );
    
    menu.AddItem( "", "sm_tas_continue", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_stop", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_fwd", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_bwd", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_nextframe", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_prevframe", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_autostrafe", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_inctimescale", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_dectimescale", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_advanceframe", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_cp_add", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_cp_lastused", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_cp_lastcreated", ITEMDRAW_DISABLED );
    
    menu.AddItem( "", "sm_tas_menu", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_settings", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_listcmds", ITEMDRAW_DISABLED );
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_LoadRun( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserLoadSaveTas( client ) ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_TasLoad );
    menu.SetTitle( "TAS Load Menu (!tas_load)\n " );
    
    
    decl String:szMap[64];
    decl String:szPath[PLATFORM_MAX_PATH];
    decl String:szFullPath[PLATFORM_MAX_PATH];
    decl String:szInfo[32];
    
    int runid;
    int mode;
    int style;
    
    int currunid = Influx_GetClientRunId( client );
    
    int uid = Influx_GetClientId( client );
    
    GetCurrentMapSafe( szMap, sizeof( szMap ) );
    
    
    BuildPath( Path_SM, szPath, sizeof( szPath ), TAS_DIR..."/%s/%i",
        szMap,
        uid );
    
    DirectoryListing dir = OpenDirectory( szPath );
    
    
    int nFiles = 0;
    
    if ( dir != null )
    {
        decl String:szFile[128];
        
        int i;
        int dotpos;
        int len;
        
        while ( dir.GetNext( szFile, sizeof( szFile ) ) )
        {
            // . and ..
            if ( szFile[0] == '.' || szFile[0] == '\0' ) continue;
            
            // Check file extension.
            len = strlen( szFile );
            dotpos = 0;
            
            for ( i = 0; i < len; i++ )
            {
                if ( szFile[i] == '.' ) dotpos = i;
            }

            if ( !StrEqual( szFile[dotpos], ".tas", false ) ) continue;
            
            
            FormatEx( szFullPath, sizeof( szFullPath ), "%s/%s", szPath, szFile );
            
            File file = OpenFile( szFullPath, "rb" );
            
            if ( file == null )
            {
                continue;
            }
            
            
            file.Seek( TASFILE_RUNID * 4, SEEK_SET );
            
            
            file.ReadInt32( runid );
            
#if defined DEBUG
            PrintToServer( INF_DEBUG_PRE..."Read run id %i (current: %i) from file '%s'", runid, currunid, szFile );
#endif
            
            if ( currunid == runid )
            {
                file.ReadInt32( mode );
                file.ReadInt32( style );
                
                
                FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i", runid, mode, style );
                
                menu.AddItem( szInfo, szFile );
                
                ++nFiles;
            }
            
            delete file;
        }
    }
    
    if ( !nFiles )
    {
        menu.AddItem( "", "No runs to load! :(", ITEMDRAW_DISABLED );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    
    delete dir;
    
    return Plugin_Handled;
}

public Action Cmd_SaveRun( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    if ( !CanUserLoadSaveTas( client ) ) return Plugin_Handled;
    
    
    decl String:szPath[PLATFORM_MAX_PATH];
    FormatTasPath( szPath, sizeof( szPath ), Influx_GetClientId( client ), Influx_GetClientRunId( client ), Influx_GetClientMode( client ), Influx_GetClientStyle( client ) );
    
    
    if ( FileExists( szPath ) )
    {
        Menu menu = new Menu( Hndlr_TasSave_Confirm );
        
        menu.SetTitle( "Are you sure you want to overwrite previously saved version?\nFile: '...%s'\n ", szPath[16] );
        
        menu.AddItem( "", "Yes" );
        menu.AddItem( "", "No" );
        
        menu.Display( client, MENU_TIME_FOREVER );
        
        return Plugin_Handled;
    }
    
    
    SaveFramesMsg( client );
    
    return Plugin_Handled;
}
