public Action Cmd_Empty( int client, int args )
{
    return Plugin_Handled;
}

public Action Cmd_Style_Tas( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientStyle( client, STYLE_TAS );
    
    return Plugin_Handled;
}

public Action Cmd_Continue( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    ContinueOrStop( client );
    
    return Plugin_Handled;
}

public Action Cmd_Stop( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    ContinueOrStop( client );
    
    return Plugin_Handled;
}

public Action Cmd_AdvanceFrame( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    if ( CanAdvanceFrame( client ) )
    {
        AdvanceFrame( client );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Forward( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    StopClient( client );
    IncreasePlayback( client );
    
    return Plugin_Handled;
}

public Action Cmd_Backward( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    StopClient( client );
    DecreasePlayback( client );
    
    return Plugin_Handled;
}

public Action Cmd_NextFrame( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    SetFrame( client, g_iStoppedFrame[client] + 1, false );
    
    StopPlayback( client );
    
    return Plugin_Handled;
}

public Action Cmd_PrevFrame( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    SetFrame( client, g_iStoppedFrame[client] - 1, false );
    
    StopPlayback( client );
    
    return Plugin_Handled;
}

public Action Cmd_IncTimescale( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserUseTimescale( client ) ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    IncreaseTimescale( client );
    
    return Plugin_Handled;
}

public Action Cmd_DecTimescale( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserUseTimescale( client ) ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    DecreaseTimescale( client );
    
    return Plugin_Handled;
}

public Action Cmd_AutoStrafe( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    ChangeAutoStrafe( client );
    
    return Plugin_Handled;
}

public Action Cmd_CPAdd( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    AddCP( client );
    
    return Plugin_Handled;
}

public Action Cmd_CPLastUsed( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    GotoCP( client, g_iLastUsedCP[client] );
    
    return Plugin_Handled;
}

public Action Cmd_CPLastCreated( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    GotoCP( client, g_iLastCreatedCP[client] );
    
    return Plugin_Handled;
}
