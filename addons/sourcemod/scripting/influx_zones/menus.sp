#define TYPE_MODE               0
#define TYPE_STYLE              1

#define ZONE_MENU_FORMAT        "Name [Type] [Zone Id]"


stock int FillZoneMenu( Menu menu, bool bReqSettings = true, bool bZoneYouAreIn = true )
{
    int num_items = 0;
    
    ZoneType_t zonetype;
    int len = GetArrayLength_Safe( g_hZones );
    char szZone[32];
    char szType[16];
    char szDisplay[64];
    char szInfo[32];
    int uid;
    
    
    if ( bZoneYouAreIn )
    {
        menu.AddItem( "_", "Zone You Are In" );
    }
    
    for ( int i = 0; i < len; i++ )
    {
        zonetype = view_as<ZoneType_t>( g_hZones.Get( i, ZONE_TYPE ) );
        if ( bReqSettings && !ZoneTypeHasSettings( zonetype ) ) continue;
        
        
        GetZoneTypeName( zonetype, szType, sizeof( szType ) );
        
        g_hZones.GetString( i, szZone, sizeof( szZone ) );
        if ( szZone[0] == '\0' )
        {
            strcopy( szZone, sizeof( szZone ), "N/A" );
        }
        
        uid = g_hZones.Get( i, ZONE_ID );
        
        FormatEx( szDisplay, sizeof( szDisplay ), "%s [%s] [%i]",
            szZone,
            szType,
            uid );
        
        
        FormatEx( szInfo, sizeof( szInfo ), "z%i", uid );
        menu.AddItem( szInfo, szDisplay );
        
        ++num_items;
    }
    
    return num_items;
}

public Action Cmd_SaveZones( int client, int args )
{
    if ( CanUserSaveZones( client ) )
    {
        int num = SaveZones();
        
        Inf_ReplyToClient( client, "Wrote {MAINCLR1}%i{CHATCLR} zones to file/database!", num );
    }
    
    return Plugin_Handled;
}

public Action Cmd_ZoneMain( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserModifyZones( client ) ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_ZoneMain );
    menu.SetTitle( "Zone Menu\n " );
    
    // Do we have any zones?
    int len = GetArrayLength_Safe( g_hZones );
    bool bHaveZones = ( len > 0 );
    
    bool bBuilding = ( g_iBuildingType[client] != ZONETYPE_INVALID );
    
    
    menu.AddItem( "sm_createzone", "Create Zone",       ( !bBuilding )                      ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    menu.AddItem( "sm_cancelzone", "Cancel Zone",       ( bBuilding )                       ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    menu.AddItem( "sm_endzone", "End Zone\n ",          ( bBuilding )                       ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    menu.AddItem( "sm_deletezone", "Delete Zone",       ( !bBuilding && bHaveZones )        ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    
    menu.AddItem( "sm_savezones", "Save Zones\n ",      ( !bBuilding && bHaveZones )        ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    
    
    char szGrid[24];
    FormatEx( szGrid, sizeof( szGrid ), "Grid Size: %i\n ", g_nBuildingGridSize[client] );
    menu.AddItem( "grid", szGrid );
    
    
    menu.AddItem( "sm_zonesettings", "Zone Settings",   ( !bBuilding && bHaveZones )        ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    menu.AddItem( "sm_teletozone", "Teleport To A Zone",   ( bHaveZones )                   ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    
    if ( g_bLib_Zones_Beams )
    {
        menu.AddItem( INF_CMD_BEAM, "Beam Settings",    ( !bBuilding && bHaveZones )        ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
        menu.AddItem( INF_CMD_BEAM_SHOWHIDDEN, "Toggle Hidden Zones" );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_CreateZone( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserModifyZones( client ) ) return Plugin_Handled;
    
    
    if ( args )
    {
        char szArg[12];
        GetCmdArgString( szArg, sizeof( szArg ) );
        
        
        ZoneType_t type = FindZoneTypeByShortName( szArg );
        if ( type == ZONETYPE_INVALID ) return Plugin_Handled;
        
        
        Action res;
        
        Call_StartForward( g_hForward_OnZoneBuildAsk );
        Call_PushCell( client );
        Call_PushCell( type );
        Call_Finish( res );
        
        if ( res != Plugin_Continue )
        {
            return Plugin_Handled;
        }
        
        StartToBuild( client, type );
        
        Inf_OpenZoneMenu( client );
    }
    else
    {
        SetShowBuild( client );
        
        
        Menu menu = new Menu( Hndlr_CreateZone );
        menu.SetTitle( "Zone Creation\n " );
        
        char szDisplay[32];
        char szInfo[32];
        
        int len = g_hZoneTypes.Length;
        for ( int i = 0; i < len; i++ )
        {
            GetZoneTypeNameByIndex( i, szDisplay, sizeof( szDisplay ) );
            GetZoneTypeShortNameByIndex( i, szInfo, sizeof( szInfo ) );
            
            menu.AddItem( szInfo, szDisplay );
        }
        
        menu.Display( client, MENU_TIME_FOREVER );
    }
    
    return Plugin_Handled;
}

public Action Cmd_CancelZone( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserModifyZones( client ) ) return Plugin_Handled;
    
    
    // TODO: Make a menu?
    if ( g_iBuildingType[client] != ZONETYPE_INVALID )
    {
        g_iBuildingType[client] = ZONETYPE_INVALID;
    }
    
    Inf_OpenZoneMenu( client );
    
    return Plugin_Handled;
}

public Action Cmd_EndZone( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserModifyZones( client ) ) return Plugin_Handled;
    
    
    if ( g_iBuildingType[client] != ZONETYPE_INVALID )
    {
        float mins[3], maxs[3];
        
        mins = g_vecBuildingStart[client];
        
        
        if ( g_ConVar_CrosshairBuild.BoolValue )
        {
            GetEyeTrace( client, maxs );
        }
        else
        {
            GetClientAbsOrigin( client, maxs );
        }
        
        
        SnapToGrid( maxs, g_nBuildingGridSize[client], 2 );
        
        RoundVector( mins );
        RoundVector( maxs );
        
        if ( g_ConVar_HeightGrace.FloatValue != 0.0 )
        {
            if ( FloatAbs( maxs[2] - mins[2] ) < g_ConVar_HeightGrace.FloatValue )
            {
                maxs[2] = mins[2] + g_ConVar_DefZoneHeight.FloatValue;
            }
        }

        CorrectMinsMaxs( mins, maxs );
        
    
        if ( g_bLib_Zones_Beams )
        {
            decl Float:offsets[2];
            if ( Influx_GetDefaultBeamOffsets( g_iBuildingType[client], offsets ) )
            {
                mins[0] -= offsets[0];
                mins[1] -= offsets[0];
                mins[2] -= offsets[1];
                
                maxs[0] += offsets[0];
                maxs[1] += offsets[0];
                maxs[2] += offsets[1];
            }
        }
        
        
        float size[3];
        for ( int i = 0; i < 3; i++ ) size[i] = maxs[i] - mins[i];
        
        float minsize = g_ConVar_MinSize.FloatValue;
        
        if ( size[0] >= minsize && size[1] >= minsize && size[2] >= minsize )
        {
            CreateZone( client, mins, maxs, g_iBuildingType[client] );
        }
        else
        {
            //g_iBuildingType[client] = ZONETYPE_INVALID;
            
            Influx_PrintToChat( _, client, "Bad zone size! Please make the zone bigger." );
        }
    }
    
    Inf_OpenZoneMenu( client );
    
    return Plugin_Handled;
}

public Action Cmd_DeleteZone( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserModifyZones( client ) ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_DeleteZone );
    menu.SetTitle( "Zone Deletion\n"...ZONE_MENU_FORMAT..."\n " );
    
    int items = FillZoneMenu( menu, false, true );
    
    if ( !items )
    {
        delete menu;
        return Plugin_Handled;
    }
    
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_ZoneSettings( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserModifyZones( client ) ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_ZoneSettings );
    menu.SetTitle( "Zone Settings\n"...ZONE_MENU_FORMAT..."\n " );
    
    int items = FillZoneMenu( menu, true, true );
    
    if ( !items )
    {
        delete menu;
        
        Inf_OpenZoneMenu( client );
        
        return Plugin_Handled;
    }
    
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_ZoneTele( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserModifyZones( client ) ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_ZoneTele );
    menu.SetTitle( "Teleport To A Zone\n"...ZONE_MENU_FORMAT..."\n " );
    
    int items = FillZoneMenu( menu, false, false );
    
    if ( !items )
    {
        delete menu;
        return Plugin_Handled;
    }
    
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_Empty( int client, int args ) { return Plugin_Handled; }
