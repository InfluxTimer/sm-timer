#include <sourcemod>

#include <influx/core>
#include <influx/prespeed>

#undef REQUIRE_PLUGIN
#include <adminmenu>



#define PRESPEEDSETTINGS_COMMAND        "sm_prespeedsettings"


#define INVALID_MAXSPD          -1.0
#define INVALID_MAXJUMPS        -2
#define INVALID_USETRUEVEL      -1
#define INVALID_DOCAP           -1


#define MAX_GROUND_SPD      280.0
#define MIN_GROUND_TIME     0.2 // Minimum amount of time a player needs to be on the ground before we reset jumps.


#define MIN_NC_PRESPEED         250.0 // Player has to go this slow after noclipping.
#define MIN_NC_PRESPEED_SQ      MIN_NC_PRESPEED * MIN_NC_PRESPEED


//#define DEBUG


enum CappingRet_t
{
    // No capping happened.
    CAPPING_NONE = 0,

    // Capping happened made but silently. Doesn't stop timer.
    CAPPING_SILENT,
    // Capping happened and timer needs to stop.
    CAPPING_STOP
}


enum
{
    PRESPEED_RUN_ID = 0,
    
    PRESPEED_MAX,
    PRESPEED_MAXJUMPS,
    
    PRESPEED_CAP,
    PRESPEED_USETRUEVEL,
    
    PRESPEED_SIZE
};

ArrayList g_hPre;



int g_nJumps[INF_MAXPLAYERS];
float g_flLastLand[INF_MAXPLAYERS];
bool g_bUsedNoclip[INF_MAXPLAYERS];

float g_flLastPrint[INF_MAXPLAYERS];



// CONVARS
ConVar g_ConVar_MaxJumps;
ConVar g_ConVar_Max;
ConVar g_ConVar_UseTrueVel;
ConVar g_ConVar_Cap;
ConVar g_ConVar_Noclip;
ConVar g_ConVar_AlwaysActive;


// FORWARDS
Handle g_hForward_OnLimitClientPrespeed;


// ADMIN MENU
TopMenu g_hTopMenu;


bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Prespeed",
    description = "Handles prespeed.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    g_bLate = late;
    
    
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_PRESPEED );
}

public void OnPluginStart()
{
    g_hPre = new ArrayList( PRESPEED_SIZE );
    
    
    // PHRASES
    LoadTranslations( INFLUX_PHRASES );
    
    
    // FORWARDS
    g_hForward_OnLimitClientPrespeed = CreateGlobalForward( "Influx_OnLimitClientPrespeed", ET_Hook, Param_Cell, Param_Cell );
    
    
    // CONVARS
    g_ConVar_MaxJumps = CreateConVar( "influx_prespeed_maxjumps", "-1", "Maximum number of jumps a player can do before starting a run? -1 = disable", FCVAR_NOTIFY, true, -1.0 );
    g_ConVar_Max = CreateConVar( "influx_prespeed_max", "300", "Default max prespeed. 0 = disable", FCVAR_NOTIFY, true, 0.0 );
    g_ConVar_UseTrueVel = CreateConVar( "influx_prespeed_usetruevel", "0", "Use truevel when checking player's speed.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_Cap = CreateConVar( "influx_prespeed_cap", "1", "0 = Timer is not started, 1 = Player's speed is capped", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_Noclip = CreateConVar( "influx_prespeed_noclip", "1", "If true, don't allow players to prespeed with noclip.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_AlwaysActive = CreateConVar( "influx_prespeed_alwaysactive", "0", "If true, stop player's prespeed immediately even inside the start zone.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    AutoExecConfig( true, "prespeed", "influx" );
    
    
    // EVENTS
    HookEvent( "player_jump", E_PlayerJump );
    
    
    // MENUS
    RegConsoleCmd( PRESPEEDSETTINGS_COMMAND, Cmd_Menu_PrespeedSettings );
    
    
    if ( g_bLate )
    {
        TopMenu topmenu;
        if ( LibraryExists( "adminmenu" ) && (topmenu = GetAdminTopMenu()) != null )
        {
            OnAdminMenuReady( topmenu );
        }
        
        
        // If core has already loaded runs
        // register runs ourselves.
        if ( Influx_HasLoadedRuns() )
        {
            Influx_OnPreRunLoad();
            
            ArrayList runs = Influx_GetRunsArray();
            int len = runs.Length;
            
            for ( int i = 0; i < len; i++ )
            {
                Influx_OnRunCreated( runs.Get( i, RUN_ID ) );
            }    
        }


        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) )
            {
                OnClientPutInServer( i );
            }
        }
    }
}

public void OnAdminMenuReady( Handle hTopMenu )
{
    TopMenu topmenu = TopMenu.FromHandle( hTopMenu );
    
    if ( topmenu == g_hTopMenu )
        return;
    
    TopMenuObject res = topmenu.FindCategory( INFLUX_ADMMENU );
    
    if ( res == INVALID_TOPMENUOBJECT )
    {
        return;
    }
    
    
    g_hTopMenu = topmenu;
    g_hTopMenu.AddItem( PRESPEEDSETTINGS_COMMAND, AdmMenu_PrespeedMenu, res, INF_PRIVCOM_RUNSETTINGS, 0 );
}

public void AdmMenu_PrespeedMenu( TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength )
{
    if ( action == TopMenuAction_DisplayOption )
    {
        strcopy( buffer, maxlength, "Prespeed Settings" );
    }
    else if ( action == TopMenuAction_SelectOption )
    {
        FakeClientCommand( client, PRESPEEDSETTINGS_COMMAND );
    }
}

public void OnClientPutInServer( int client )
{
    g_nJumps[client] = 0;
    g_flLastLand[client] = 0.0;

    g_flLastPrint[client] = 0.0;
    
    if ( !IsFakeClient( client ) )
    {
        Inf_SDKHook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client );
    }
}

public void Influx_OnPreRunLoad()
{
    g_hPre.Clear();
}

public void Influx_OnRunCreated( int runid )
{
    if ( FindPreById( runid ) != -1 ) return;
    
    
    decl data[PRESPEED_SIZE];
    
    data[PRESPEED_RUN_ID] = runid;
    
    data[PRESPEED_MAX] = view_as<int>( INVALID_MAXSPD );
    data[PRESPEED_MAXJUMPS] = INVALID_MAXJUMPS;
    data[PRESPEED_USETRUEVEL] = INVALID_USETRUEVEL;
    data[PRESPEED_CAP] = INVALID_DOCAP;
    
    g_hPre.PushArray( data );
}

public void Influx_OnRunDeleted( int runid )
{
    int index = FindPreById( runid );
    if ( index != -1 )
    {
        g_hPre.Erase( index );
    }
}

public void Influx_OnRunLoad( int runid, KeyValues kv )
{
    if ( FindPreById( runid ) != -1 ) return;
    
    
    decl data[PRESPEED_SIZE];
    
    data[PRESPEED_RUN_ID] = runid;
    
    data[PRESPEED_MAX] = view_as<int>( kv.GetFloat( "prespeed_max", INVALID_MAXSPD ) );
    data[PRESPEED_MAXJUMPS] = kv.GetNum( "prespeed_maxjumps", INVALID_MAXJUMPS );
    data[PRESPEED_USETRUEVEL] = kv.GetNum( "prespeed_usetruevel", INVALID_USETRUEVEL );
    data[PRESPEED_CAP] = kv.GetNum( "prespeed_cap", INVALID_DOCAP );
    
    g_hPre.PushArray( data );
}

public void Influx_OnRunSave( int runid, KeyValues kv )
{
    int index = FindPreById( runid );
    if ( index == -1 ) return;
    
    
    decl data[PRESPEED_SIZE];
    g_hPre.GetArray( index, data );
    
    float maxprespd = view_as<float>( data[PRESPEED_MAX] );
    int maxjumps = data[PRESPEED_MAXJUMPS];
    int truevel = data[PRESPEED_USETRUEVEL];
    int cap = data[PRESPEED_CAP];
    
    if ( maxprespd != INVALID_MAXSPD && maxprespd != g_ConVar_Max.FloatValue )
    {
        kv.SetFloat( "prespeed_max", maxprespd );
    }
    
    if ( maxjumps != INVALID_MAXJUMPS && maxjumps != g_ConVar_MaxJumps.IntValue )
    {
        kv.SetNum( "prespeed_maxjumps", maxjumps );
    }
    
    if ( truevel != INVALID_USETRUEVEL && truevel != g_ConVar_UseTrueVel.IntValue )
    {
        kv.SetNum( "prespeed_usetruevel", truevel ? 1 : 0 );
    }
    
    if ( cap != INVALID_DOCAP && cap != g_ConVar_Cap.IntValue )
    {
        kv.SetNum( "prespeed_cap", cap );
    }
}

public Action Influx_OnTimerStart( int client, int runid, char[] errormsg, int error_len )
{
    CappingRet_t ret = PerformCapping(
        client,
        runid,
        errormsg,
        error_len,
        true );

    return ret == CAPPING_STOP ? Plugin_Handled : Plugin_Continue;
}

public Action OnPlayerRunCmd( int client )
{
    if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
    
    
    static int fLastFlags[INF_MAXPLAYERS];
    
    
    int flags = GetEntityFlags( client );
    
    
    if ( !(fLastFlags[client] & FL_ONGROUND) && flags & FL_ONGROUND )
    {
        g_flLastLand[client] = GetEngineTime();
    }
    
    
    if ( g_nJumps[client] > 0 )
    {
        if (flags & FL_ONGROUND
        &&  GetEntitySpeed( client ) < MAX_GROUND_SPD
        &&  (GetEngineTime() - g_flLastLand[client]) > MIN_GROUND_TIME )
        {
#if defined DEBUG
            PrintToServer( INF_DEBUG_PRE..."Resetting player's %i jumps. (%i)", client, g_nJumps[client] );
#endif
            g_nJumps[client] = 0;
        }
    }
    
    
    fLastFlags[client] = flags;
    
    return Plugin_Continue;
}

public void E_PlayerJump( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( GetEventInt( event, "userid" ) );
    if ( !client ) return;
    
    if ( !IsPlayerAlive( client ) ) return;
    
    
    ++g_nJumps[client];
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Player %i has jumped consecutively %i times.", client, g_nJumps[client] );
#endif
}

public void E_PreThinkPost_Client( int client )
{
    if ( GetEntityMoveType( client ) == MOVETYPE_NOCLIP )
    {
        g_bUsedNoclip[client] = true;
    }
    else if ( g_bUsedNoclip[client] && GetEntityTrueSpeedSquared( client ) < MIN_NC_PRESPEED_SQ )
    {
        g_bUsedNoclip[client] = false;
    }

    // Always active prespeed checking.
    if ( g_ConVar_AlwaysActive.BoolValue && Influx_GetClientState( client ) == STATE_START )
    {
        static char szError[256];
        szError[0] = 0;

        CappingRet_t ret = PerformCapping(
            client,
            Influx_GetClientRunId( client ),
            szError,
            sizeof( szError ),
            false );

        if ( ret == CAPPING_STOP )
        {
            Influx_SetClientState( client, STATE_NONE );
        }

        if ( szError[0] != 0 && ShouldPrintMsg( client ) )
        {
            Influx_PrintToChat( _, client, "%s", szError );
            g_flLastPrint[client] = GetEngineTime();
        }
    }
}

stock int FindPreById( int id )
{
    int len = g_hPre.Length;
    if ( len > 0 )
    {
        for ( int i = 0; i < len; i++ )
        {
            if ( g_hPre.Get( i, PRESPEED_RUN_ID ) == id ) return i;
        }
    }
    
    return -1;
}

stock bool SendLimitForward( int client, bool bUsedNoclip )
{
    Action res = Plugin_Continue;
    
    Call_StartForward( g_hForward_OnLimitClientPrespeed );
    Call_PushCell( client );
    Call_PushCell( bUsedNoclip );
    Call_Finish( res );
    
    
    return ( res == Plugin_Continue ) ? true : false
}

stock int GetDefaultMaxJumps()
{
    return;
}

stock void GetMaxJumpsName( int maxjumps, char[] buffer, int len )
{
    if ( maxjumps < 0 )
    {
        strcopy( buffer, len, "No limit" );
        return;
    }
    
    FormatEx( buffer, len, "%i jump(s)", maxjumps );
}

stock int GetMaxJumps( any data[PRESPEED_SIZE] )
{
    return data[PRESPEED_MAXJUMPS] == INVALID_MAXJUMPS ? g_ConVar_MaxJumps.IntValue : data[PRESPEED_MAXJUMPS];
}

stock int GetMaxJumpsByIndexSafe( int index )
{
    if ( index == -1 )
        return g_ConVar_MaxJumps.IntValue;

    int jumps = g_hPre.Get( index, PRESPEED_MAXJUMPS );
    return ( jumps == INVALID_MAXJUMPS ) ? g_ConVar_MaxJumps.IntValue : jumps;
}

stock float GetMaxSpeed( any data[PRESPEED_SIZE] )
{
    return view_as<float>( data[PRESPEED_MAX] ) == INVALID_MAXSPD ? g_ConVar_Max.FloatValue : view_as<float>( data[PRESPEED_MAX] );
}

stock float GetMaxSpeedByIndexSafe( int index )
{
    if ( index == -1 )
        return g_ConVar_Max.FloatValue;

    float spd = g_hPre.Get( index, PRESPEED_MAX );
    return ( spd == INVALID_MAXSPD ) ? g_ConVar_Max.FloatValue : spd;
}

stock int GetUseTrueVelByIndexSafe( int index )
{
    if ( index == -1 )
        return g_ConVar_UseTrueVel.IntValue;

    int usetruevel = g_hPre.Get( index, PRESPEED_USETRUEVEL );
    return ( usetruevel == INVALID_USETRUEVEL ) ? g_ConVar_UseTrueVel.IntValue : usetruevel;
}

stock int GetCapStyleByIndexSafe( int index )
{
    if ( index == -1 )
        return g_ConVar_Cap.IntValue;

    int capstyle = g_hPre.Get( index, PRESPEED_CAP );
    return ( capstyle == INVALID_DOCAP ) ? g_ConVar_Cap.IntValue : capstyle;
}

stock bool CanUserModifyPrespeedSettings( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_RUNSETTINGS, ADMFLAG_ROOT );
}

stock void StartCheckPrespeed( int client, float maxprespd, bool bUseTrueVel )
{
    DataPack pack = new DataPack();
    pack.WriteCell( GetClientUserId( client ) );
    pack.WriteFloat( maxprespd );
    pack.WriteCell( bUseTrueVel );
    pack.Reset( false );
    
    RequestFrame( CheckPrespeed, pack );
}

stock CappingRet_t PerformCapping( int client, int runid, char[] errormsg, int error_len, bool bOnStart )
{
    // This should never occur.
    int index = FindPreById( runid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Couldn't find prespeed settings for run %i! Using defaults...", runid );
    }
    

    if ( g_ConVar_Noclip.BoolValue && g_bUsedNoclip[client] )
    {
        FormatEx( errormsg, error_len, "%T", "INF_PRESPEEDNONOCLIP", client );
        return CAPPING_STOP;
    }
    
    
    // Check jump count.
    int maxjumps = GetMaxJumpsByIndexSafe( index );
    
    
    if ( maxjumps >= 0 )
    {
        if ( g_nJumps[client] > maxjumps )
        {
            if ( SendLimitForward( client, g_bUsedNoclip[client] ) )
            {
                if ( maxjumps )
                {
                    FormatEx( errormsg, error_len, "%T", "INF_PRESPEEDJUMPLIMIT", client, maxjumps );
                }
                else
                {
                    FormatEx( errormsg, error_len, "%T", "INF_PRESPEEDNOJUMP", client );
                }
                
                
                return CAPPING_STOP;
            }
        }
    }
    
    
    // Check prespeed.
    float maxprespd = GetMaxSpeedByIndexSafe( index );
    
    
    if ( maxprespd > 0.0 )
    {
        int usetruevel = GetUseTrueVelByIndexSafe( index );
        
        
        // Just check if we're going over the prespeed limit.
        bool bBadSpd = CapClientSpeed( client, maxprespd, usetruevel != 0, true );
        
        if ( bBadSpd )
        {
#if defined DEBUG
            PrintToServer( INF_DEBUG_PRE..."Bad prespeed (%i) (Max: %.1f)", client, maxprespd );
#endif
            
            int capstyle = GetCapStyleByIndexSafe( index );
            
            
            if ( SendLimitForward( client, g_bUsedNoclip[client] ) )
            {
                if ( capstyle )
                {
                    // Do the actual capping.
                    CapClientSpeed( client, maxprespd, usetruevel != 0 );
                    
                    //
                    // We need to check whether the capping worked.
                    // TeleportEntity works, but it's possible that the player's
                    // origin/angles/velocity won't change (next frame?).
                    // I have no idea why this happens.                   
                    //
                    if ( bOnStart )
                    {
                        StartCheckPrespeed( client, maxprespd, usetruevel != 0 );
                    }

                    return CAPPING_SILENT;
                }
                else
                {
                    FormatEx( errormsg, error_len, "%T", "INF_PRESPEEDEXCEED", client, RoundFloat( maxprespd ) );
                    FormatEx( errormsg, error_len, "Your prespeed cannot exceed {MAINCLR1}%.0f{CHATCLR}!", maxprespd );
                    return CAPPING_STOP;
                }
            }
        }
    }

    return CAPPING_NONE;
}

stock void CheckPrespeed( DataPack pack )
{
    int client = GetClientOfUserId( pack.ReadCell() );
    float maxprespd = pack.ReadFloat();
    bool bUseTrueVel = pack.ReadCell() != 0;
    pack.Reset();
    
    if ( client < 1 || !IsClientInGame( client ) )
    {
        delete pack;
        return;
    }
    
    if ( !CapClientSpeed( client, maxprespd, bUseTrueVel ) )
    {
        delete pack;
        return;
    }
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Capped player %i speed again!", client );
#endif

    // Keep checking our speed until we're not going faster.
    RequestFrame( CheckPrespeed, pack );
}

stock bool CapClientSpeed( int client, float maxprespd, bool bUseTrueVel, bool bJustCheck = false )
{
    float vel[3];
    GetEntityVelocity( client, vel );
    
    float truespd = SquareRoot( vel[0] * vel[0] + vel[1] * vel[1] + vel[2] * vel[2] );
    float spd = SquareRoot( vel[0] * vel[0] + vel[1] * vel[1] );
    
    
    bool bBadSpd = false;
    if ( bUseTrueVel )
    {
        bBadSpd = ( truespd > maxprespd );
    }
    else
    {
        bBadSpd = ( spd > maxprespd );
    }
    
    
    // We're within the prespeed limit, all good.
    if ( !bBadSpd )
    {
        return false;
    }
    
    
    // Caller just wanted to know whether we have a bad prespeed.
    // Return early.
    if ( bJustCheck )
    {
        return true;
    }
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Capping player %i speed to %.0f!", client, maxprespd );
#endif
    
    
    float newvel[3];
    CapVelocity( vel, newvel, maxprespd, bUseTrueVel );
    
    TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, newvel );
    
    return true;
}

stock void CapVelocity( const float vel[3], float out[3], float maxprespd, bool bUseTrueVel )
{
    if ( bUseTrueVel )
    {
        float temp[3];
        NormalizeVector( vel, temp );
        ScaleVector( temp, maxprespd );
        
        out = temp;
        
        return;
    }
    
    
    
    float wanted[3];
    
    wanted[0] = vel[0];
    wanted[1] = vel[1];
    wanted[2] = 0.0;
    
    NormalizeVector( wanted, wanted );
    ScaleVector( wanted, maxprespd );
    
    wanted[2] = vel[2];
    
    out = wanted;
}

stock bool ShouldPrintMsg( int client )
{
    return ( GetEngineTime() - g_flLastPrint[client] ) > 1.0;
}

public Action Cmd_Menu_PrespeedSettings( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserModifyPrespeedSettings( client ) )
    {
        return Plugin_Handled;
    }
    
    
    // Player is not in a valid run.
    int runid = Influx_GetClientRunId( client );
    int ipre = FindPreById( runid );
    if ( ipre == -1 )
    {
        return Plugin_Handled;
    }
    
    
    decl data[PRESPEED_SIZE];
    g_hPre.GetArray( ipre, data );
    
    
    Menu menu = new Menu( Hndlr_PrespeedSettings );
    
    char szRun[MAX_RUN_NAME];
    char szMaxSpeed[128];
    char szMaxJumps[128];
    
    
    //
    // Speed
    //
    float maxspd = GetMaxSpeed( data );
    if ( maxspd <= 0.0 )
    {
        strcopy( szMaxSpeed, sizeof( szMaxSpeed ), "No limit" );
    }
    else
    {
        FormatEx( szMaxSpeed, sizeof( szMaxSpeed ), "%.0f", maxspd );
    }
    
    
    if ( view_as<float>( data[PRESPEED_MAX] ) == INVALID_MAXSPD )
    {
        Format( szMaxSpeed, sizeof( szMaxSpeed ), "Default (%s)", szMaxSpeed );
    }
    
    
    //
    // Jumps
    //
    int maxjumps = GetMaxJumps( data );
    GetMaxJumpsName( maxjumps, szMaxJumps, sizeof( szMaxJumps ) );
    
    if ( data[PRESPEED_MAXJUMPS] == INVALID_MAXJUMPS )
    {
        Format( szMaxJumps, sizeof( szMaxJumps ), "Default (%s)", szMaxJumps );
    }
    
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    menu.SetTitle( "Prespeed Settings: %s\n \nMax Speed: %s\nMax Jumps: %s\n \n ", szRun, szMaxSpeed, szMaxJumps );
    
    
    // ITEMDRAW_DISABLED | ITEMDRAW_DEFAULT
    menu.AddItem( "a", "> Increase Max Speed" );
    menu.AddItem( "b", "< Decrease Max Speed" );
    menu.AddItem( "c", "Use Default Max Speed\n " );
    
    menu.AddItem( "d", "> Increase Max Jumps" );
    menu.AddItem( "e", "< Decrease Max Jumps" );
    menu.AddItem( "f", "Use Default Max Jumps" );
    
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Hndlr_PrespeedSettings( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !CanUserModifyPrespeedSettings( client ) )
        return 0;
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) )
        return 0;
    
    
    int runid = Influx_GetClientRunId( client );
    int ipre = FindPreById( runid );
    if ( ipre == -1 )
        return 0;
    
    
    decl data[PRESPEED_SIZE];
    g_hPre.GetArray( ipre, data );
    
    switch ( szInfo[0] )
    {
        case 'a' : // Increase max speed
        {
            float maxspd = GetMaxSpeed( data );
            maxspd += 50.0;
            
            g_hPre.Set( ipre, maxspd, PRESPEED_MAX );
        }
        case 'b' : // Decrease max speed
        {
            float maxspd = GetMaxSpeed( data );
            maxspd -= 50.0;
            if ( maxspd < 0.0 )
                maxspd = 0.0;
            
            g_hPre.Set( ipre, maxspd, PRESPEED_MAX );
        }
        case 'c' : // Use default max speed
        {
            g_hPre.Set( ipre, INVALID_MAXSPD, PRESPEED_MAX );
        }
        case 'd' : // Increase max jumps
        {
            int maxjumps = GetMaxJumps( data ) + 1;
            
            g_hPre.Set( ipre, maxjumps, PRESPEED_MAXJUMPS );
        }
        case 'e' : // Decrease max jumps
        {
            int maxjumps = GetMaxJumps( data ) - 1;
            if ( maxjumps < -1 )
                maxjumps = -1;
            
            g_hPre.Set( ipre, maxjumps, PRESPEED_MAXJUMPS );
        }
        case 'f' : // Use default max jumps
        {
            g_hPre.Set( ipre, INVALID_MAXJUMPS, PRESPEED_MAXJUMPS );
        }
    }
    
    FakeClientCommand( client, PRESPEEDSETTINGS_COMMAND );
    
    
    return 0;
}
