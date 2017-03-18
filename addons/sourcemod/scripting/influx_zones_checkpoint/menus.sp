public Action Cmd_PrintTopCpTimes( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Inf_HandleCmdSpam( client, 3.0, g_flLastCmdTime[client], true ) )
    {
        return Plugin_Handled;
    }
    
    
    int mapid = Influx_GetCurrentMapId();
    int runid = Inf_GetClientRunIdParse( client );
    int mode = Influx_GetClientMode( client );
    int style = Influx_GetClientStyle( client );
    
    if ( args )
    {
        char szUseless[1];
        int useless;
        
        
        decl String:szMap[64];
        szMap[0] = 0;
        
        int runidp = -1;
        
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
        
        DB_PrintTopCPTimes( client, mapid, runid, mode, style, szMap );
    }
    else
    {
        DB_PrintTopCPTimes( client, mapid, runid, mode, style );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Empty( int client, int args ) { return Plugin_Handled; }