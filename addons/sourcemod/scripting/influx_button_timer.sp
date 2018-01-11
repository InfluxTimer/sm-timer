#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>

#include <msharedutil/ents>



#define DEBUG



#define BUTTON_MODEL            "models/props_mill/freightelevatorbutton02.mdl"

#define KZMOD_BUTTON_MODEL_M    "kzmod/buttons/standing_button.mdl"
#define KZMOD_BUTTON_MODEL      "models/kzmod/buttons/standing_button.mdl"


enum ButtonType_t
{
    BTYPE_INVALID = -1,
    
    BTYPE_START,
    BTYPE_END
}



//ConVar g_ConVar_ButtonModel;

int g_EntRef_Placeholder[INF_MAXPLAYERS] = { INVALID_ENT_REFERENCE, ... };
float g_flBuildOffsetZ[INF_MAXPLAYERS];
float g_flBuildDist[INF_MAXPLAYERS];


int g_EntRef_StartButton;
int g_EntRef_EndButton;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Button | Timer",
    description = "Start the timer with a button!",
    version = INF_VERSION
};

public void OnPluginStart()
{
    //g_ConVar_ButtonModel = CreateConVar();
    
    RegAdminCmd( "sm_createbutton", Cmd_CreateButton, ADMFLAG_ROOT );
    RegAdminCmd( "sm_endbutton", Cmd_EndButton, ADMFLAG_ROOT );
    
    RegAdminCmd( "sm_setasbutton", Cmd_SetAsButton, ADMFLAG_ROOT );
}

public void OnMapStart()
{
    PrecacheModel( BUTTON_MODEL );
    
    g_EntRef_StartButton = INVALID_ENT_REFERENCE;
    g_EntRef_EndButton = INVALID_ENT_REFERENCE;
}

public void OnClientPutInServer( int client )
{
    g_EntRef_Placeholder[client] = INVALID_ENT_REFERENCE;
    
    
    g_flBuildOffsetZ[client] = 0.0;
    
    g_flBuildDist[client] = 512.0;
}

public void OnClientDisconnect( int client )
{
    UnhookPlaceholder( client );
    KillPlaceholder( client );
}

public Action Cmd_CreateButton( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    
    /*Menu menu = new Menu( Hndlr_ButtonMenu );
    
    menu.SetTitle( "Button Menu\n " );
    
    menu.AddItem( "", "Height +" );
    menu.AddItem( "", "Height -" );*/
    
    
    g_flBuildDist[client] = 256.0;
    
    
    if ( EntRefToEntIndex( g_EntRef_Placeholder[client] ) < 1 )
    {
        float pos[3];
        float ang[3];
        
        int ent = SpawnButton( pos, ang, true );
        
        if ( ent > 0 )
        {
            g_EntRef_Placeholder[client] = EntIndexToEntRef( ent );
        }
    }
    
    
    SDKHook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
    
    return Plugin_Handled;
}

public Action Cmd_EndButton( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    UnhookPlaceholder( client );
    KillPlaceholder( client );
    
    
    float pos[3];
    float ang[3];
    if ( !GetBuildPosition( client, pos, ang ) ) return Plugin_Handled;
    
    
    int ent = SpawnButton( pos, ang );
    
    if ( ent > 0 )
    {
        SetAsButton( ent, BTYPE_END );
    }
    
    return Plugin_Handled;
}

public Action Cmd_SetAsButton( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( !DoCrosshairTrace( client ) ) return Plugin_Handled;
    
    
    int ent = TR_GetEntityIndex();
    
    
    if ( !IsValidMapButton( ent ) )
    {
        PrintToServer( "Invalid map button (%i)!", ent );
        return Plugin_Handled;
    }
    
    
    SetAsButton( ent, BTYPE_START );
    
    
    return Plugin_Handled;
}

public void E_PostThinkPost_Client( int client )
{
    int ent = EntRefToEntIndex( g_EntRef_Placeholder[client] );
    
    if ( ent < 1 )
    {
        UnhookPlaceholder( client );
        KillPlaceholder( client );
        return;
    }
    
    int buttons = GetEntProp( client, Prop_Data, "m_nOldButtons" );
    
    if ( buttons & IN_ATTACK )
    {
        g_flBuildDist[client] += 1.0;
    }
    else if ( buttons & IN_ATTACK2 )
    {
        g_flBuildDist[client] -= 1.0;
    }
    
    
    decl Float:pos[3], Float:ang[3];
    if ( !GetBuildPosition( client, pos, ang ) ) return;
    
    
    TeleportEntity( ent, pos, ang, NULL_VECTOR );
}

stock bool GetBuildPosition( int client, float pos[3], float ang[3] )
{
    if ( !DoCrosshairTrace( client, EntRefToEntIndex( g_EntRef_Placeholder[client] ) ) ) return false;
    
    
    TR_GetEndPosition( pos );
    
    decl Float:eyepos[3];
    GetClientEyePosition( client, eyepos );
    
    if ( GetVectorDistance( eyepos, pos ) > g_flBuildDist[client] )
    {
        decl Float:eye[3];
        GetClientEyeAngles( client, eye );
        
        decl Float:fwd[3];
        GetAngleVectors( eye, fwd, NULL_VECTOR, NULL_VECTOR );
        
        for ( int i = 0; i < 3; i++ )
        {
            pos[i] = eyepos[i] + fwd[i] * g_flBuildDist[client];
        }
    }
    
    
    pos[2] += g_flBuildOffsetZ[client];
    
    
    GetClientEyeAngles( client, ang );
    
    ang[0] = 0.0;
    ang[1] += 180.0;
    ang[2] = 0.0;
    
    return true;
}

public void E_UsePost_Start( int ent, int activator, int caller, UseType type, float value )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
#if defined DEBUG
    PrintToServer( "Player %i has pressed start button %i!", activator, ent );
#endif

    Influx_StartTimer( activator, 1 );
}

public void E_UsePost_End( int ent, int activator, int caller, UseType type, float value )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
#if defined DEBUG
    PrintToServer( "Player %i has pressed end button %i!", activator, ent );
#endif

    Influx_FinishTimer( activator, 1 );
}

stock int SpawnButton( const float pos[3], const float ang[3], bool fake = false )
{
    int ent = CreateEntityByName( "prop_physics_override" );
    
    if ( ent == -1 )
    {
        LogError( INF_CON_PRE..."Couldn't create button entity!" );
        return -1;
    }
    
    
#define SF_DEBRIS   4
#define SF_MOTIONDISABLED   8
#define SF_FIREUSE          256

    int flags = SF_MOTIONDISABLED;
    
    if ( fake )
    {
        flags |= SF_DEBRIS;
    }
    else
    {
        flags |= SF_FIREUSE;
    }

    char spawnflags[32];
    FormatEx( spawnflags, sizeof( spawnflags ), "%i", flags );
    
    DispatchKeyValue( ent, "spawnflags", spawnflags );
    
    if ( IsGenericPrecached( KZMOD_BUTTON_MODEL ) )
    {
        DispatchKeyValue( ent, "model", KZMOD_BUTTON_MODEL );
    }
    else
    {
        DispatchKeyValue( ent, "model", BUTTON_MODEL );
    }
    
    
    /*if ( fake )
    {
        DispatchKeyValue( ent, "solid", "0" );
    }*/
    
    DispatchSpawn( ent );
    
    ActivateEntity( ent );
    
    
    if ( fake )
    {
        SetEntityRenderMode( ent, RENDER_TRANSCOLOR );
        SetEntityRenderColor( ent, 255, 255, 255, 225 );
    }
    
    
    TeleportEntity( ent, pos, ang, NULL_VECTOR );
    
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Spawned button %i @ {%.1f, %.1f, %.1f}", ent, pos[0], pos[1], pos[2] );
#endif
    
    return ent;
}

stock bool DoCrosshairTrace( int client, int ignore = -1 )
{
    decl Float:pos[3];
    GetClientEyePosition( client, pos );
    
    decl Float:ang[3];
    GetClientEyeAngles( client, ang );
    
    TR_TraceRayFilter( pos, ang, MASK_SOLID, RayType_Infinite, TraceFilter_Button, ignore );
    
    return TR_DidHit();
}

stock void SetAsButton( int ent, ButtonType_t buttontype )
{
#if defined DEBUG
    PrintToServer( INF_CON_PRE..."Setting %i as %i!", ent, buttontype );
#endif

    bool hadrun = HaveStartAndEnd();
    
    switch ( buttontype )
    {
        case BTYPE_START :
        {
            g_EntRef_StartButton = EntIndexToEntRef( ent );
            
            SDKHook( ent, SDKHook_UsePost, E_UsePost_Start );
        }
        case BTYPE_END :
        {
            g_EntRef_EndButton = EntIndexToEntRef( ent );
            
            SDKHook( ent, SDKHook_UsePost, E_UsePost_End );
        }
    }
    
    
    if ( !hadrun && HaveStartAndEnd() )
    {
#if defined DEBUG
        PrintToServer( INF_CON_PRE..."Creating run from buttons!" );
#endif

        //Influx_AddRun( _, _, view_as<float>( {0.0,0.0,0.0} ) );
    }
}

stock bool HaveStartAndEnd()
{
    int start = EntRefToEntIndex( g_EntRef_StartButton );
    int end = EntRefToEntIndex( g_EntRef_EndButton );
    
    return ( start > 0 && end > 0 );
}

stock bool IsValidMapButton( int ent )
{
    if ( ent <= MaxClients ) return false;
    
    
    char szClass[64];
    GetEntityClassname( ent, szClass, sizeof( szClass ) );
    
    return StrEqual( szClass, "func_button" );
}

stock void UnhookPlaceholder( int client )
{
    SDKUnhook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
}

stock void KillPlaceholder( int client )
{
    int ent = EntRefToEntIndex( g_EntRef_Placeholder[client] );
    
    if ( ent > 0 )
    {
        KillEntity( ent );
    }
    
    g_EntRef_Placeholder[client] = INVALID_ENT_REFERENCE;
}

public bool TraceFilter_Button( int ent, int mask, int ignore )
{
    return ( ent != ignore && (ent == 0 || ent > MaxClients) );
}