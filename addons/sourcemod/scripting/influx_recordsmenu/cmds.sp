public Action Cmd_PrintMyRecords( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Inf_HandleCmdSpam( client, 3.0, g_flLastRecPrintTime[client], true ) )
    {
        return Plugin_Handled;
    }
    
    
    int uid = Influx_GetClientId( client );
    if ( uid < 1 ) return Plugin_Handled;
    
    
    int mapid = Influx_GetCurrentMapId();
    int runid = Inf_GetClientRunIdParse( client );
    
    
    if ( args )
    {
        char szUseless[1];
        int useless;
        
        
        decl String:szMap[64];
        szMap[0] = '\0'; 
        
        
        int runidp = -1;
        int mode = -1;
        int style = -1;
        
        
        Inf_ParseArgs( args, 3, useless, mapid, runidp, mode, style, szUseless, 1, szMap, sizeof( szMap ) );
        
        if ( szMap[0] != 0 )
        {
            mapid = -1;
            runid = MAIN_RUN_ID;
        }
        
        if ( runidp != -1 )
        {
            runid = runidp;
        }
        
        DB_PrintRecords( client, uid, mapid, runid, mode, style, _, szMap );
    }
    else
    {
        DB_DetermineRunMenu( client, uid, mapid, runid );
    }
    
    return Plugin_Handled;
}

public Action Cmd_PrintMyMapsRecords( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Inf_HandleCmdSpam( client, 3.0, g_flLastRecPrintTime[client], true ) )
    {
        return Plugin_Handled;
    }
    
    int uid = Influx_GetClientId( client );
    if ( uid < 1 ) return Plugin_Handled;
    
    
    DB_PrintMaps( client, uid );
    
    return Plugin_Handled;
}

public Action Cmd_PrintRecords( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Inf_HandleCmdSpam( client, 3.0, g_flLastRecPrintTime[client], true ) )
    {
        return Plugin_Handled;
    }
    
    
    int mapid = Influx_GetCurrentMapId();
    int runid = Inf_GetClientRunIdParse( client );
    
    
    if ( args )
    {
        decl String:szMap[64];
        szMap[0] = '\0';
        
        decl String:szName[64];
        szName[0] = '\0';
        
        int uid = -1;
        int runidp = -1;
        int mode = -1;
        int style = -1;
        
        Inf_ParseArgs( args, 3, uid, mapid, runidp, mode, style, szName, sizeof( szName ), szMap, sizeof( szMap ) );
        
        if ( szMap[0] != 0 )
        {
            mapid = -1;
            runid = MAIN_RUN_ID;
        }
        
        if ( runidp != -1 )
        {
            runid = runidp;
        }
        
        DB_PrintRecords( client, uid, mapid, runid, mode, style, szName, szMap );
    }
    else
    {
        DB_DetermineRunMenu( client, _, mapid, runid );
    }
    
    return Plugin_Handled;
}

public Action Cmd_PrintMapsRecords( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Inf_HandleCmdSpam( client, 3.0, g_flLastRecPrintTime[client], true ) )
    {
        return Plugin_Handled;
    }
    
    
    DB_PrintMaps( client );
    
    return Plugin_Handled;
}
