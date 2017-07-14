#define ZONE_WIDTH                  1.0

#define CLR4_WHITE                  { 255, 255, 255, 255 }


public Action T_DrawBuildBeams( Handle hTimer, int client )
{
    if ( !IsClientInGame( client ) )
    {
        g_iBuildingType[client] = ZONETYPE_INVALID;
        return Plugin_Stop;
    }
    
    if ( g_iBuildingType[client] == ZONETYPE_INVALID )
    {
        return Plugin_Stop;
    }
    
    
    decl Float:p1[3], Float:p2[3], Float:p3[3], Float:p4[3], Float:p5[3], Float:p6[3], Float:p7[3], Float:p8[3];
    
    p1 = g_vecBuildingStart[client];
    p1[2] += 1.0;
    
    
    if ( g_ConVar_CrosshairBuild.BoolValue )
    {
        HandleTraceDist( client );
        GetEyeTrace( client, p7 );
    }
    else
    {
        GetClientAbsOrigin( client, p7 );
    }
    
    if ( g_ConVar_HeightGrace.FloatValue != 0.0 )
    {
        if ( FloatAbs( p1[2] - p7[2] ) < g_ConVar_HeightGrace.FloatValue )
        {
            p7[2] += g_ConVar_DefZoneHeight.FloatValue;
        }
    }
    
    SnapToGrid( p7, g_nBuildingGridSize[client], 2 );
    
    
    p3[0] = p7[0];
    p3[1] = p7[1];
    p3[2] = p1[2];
    
    p2[0] = p1[0];
    p2[1] = p7[1];
    p2[2] = p1[2];
    
    p4[0] = p7[0];
    p4[1] = p1[1];
    p4[2] = p1[2];
    
    
    p5 = p1; p5[2] = p7[2];
    
    p6 = p2; p6[2] = p7[2];
    
    p8 = p4; p8[2] = p7[2];
    
    
    TE_SetupBeamPoints( p1, p2, g_iBuildBeamMat, 0, 0, 0, ZONE_BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, CLR4_WHITE, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( p2, p3, g_iBuildBeamMat, 0, 0, 0, ZONE_BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, CLR4_WHITE, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( p3, p4, g_iBuildBeamMat, 0, 0, 0, ZONE_BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, CLR4_WHITE, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( p4, p1, g_iBuildBeamMat, 0, 0, 0, ZONE_BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, CLR4_WHITE, 0 );
    TE_SendToAll( 0.0 );
    
    TE_SetupBeamPoints( p5, p6, g_iBuildBeamMat, 0, 0, 0, ZONE_BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, CLR4_WHITE, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( p6, p7, g_iBuildBeamMat, 0, 0, 0, ZONE_BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, CLR4_WHITE, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( p7, p8, g_iBuildBeamMat, 0, 0, 0, ZONE_BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, CLR4_WHITE, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( p8, p5, g_iBuildBeamMat, 0, 0, 0, ZONE_BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, CLR4_WHITE, 0 );
    TE_SendToAll( 0.0 );
    
    TE_SetupBeamPoints( p1, p5, g_iBuildBeamMat, 0, 0, 0, ZONE_BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, CLR4_WHITE, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( p2, p6, g_iBuildBeamMat, 0, 0, 0, ZONE_BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, CLR4_WHITE, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( p3, p7, g_iBuildBeamMat, 0, 0, 0, ZONE_BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, CLR4_WHITE, 0 );
    TE_SendToAll( 0.0 );
    TE_SetupBeamPoints( p4, p8, g_iBuildBeamMat, 0, 0, 0, ZONE_BUILDDRAW_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, CLR4_WHITE, 0 );
    TE_SendToAll( 0.0 );
    
    return Plugin_Continue;
}

public Action T_DrawBuildStart( Handle hTimer, int client )
{
    if ( !IsClientInGame( client ) )
    {
        g_iBuildingType[client] = ZONETYPE_INVALID;
        return Plugin_Stop;
    }
    
    if ( !g_bShowSprite[client] )
    {
        return Plugin_Stop;
    }
    
    

    decl Float:pos[3];
    if ( g_ConVar_CrosshairBuild.BoolValue )
    {
        HandleTraceDist( client );
        
        GetEyeTrace( client, pos );
    }
    else
    {
        GetClientAbsOrigin( client, pos );
    }
    
    SnapToGrid( pos, g_nBuildingGridSize[client], 2 );
    
    
    DrawBuildSprite( pos );
    
    return Plugin_Continue;
}

stock void DrawBuildSprite( const float pos[3] )
{
    TE_SetupGlowSprite( pos, g_iBuildSprite, ZONE_BUILDDRAW_INTERVAL, g_ConVar_SpriteSize.FloatValue, 255 );
    TE_SendToAll( 0.0 );
}