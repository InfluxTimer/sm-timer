#include <sourcemod>

#include <influx/core>
#include <influx/hud_draw>

#include <msharedutil/misc>


#undef REQUIRE_PLUGIN
#include <influx/hud>
#include <influx/help>
#include <influx/recording>
#include <influx/strafes>
#include <influx/jumps>
#include <influx/pause>
#include <influx/practise>
#include <influx/strfsync>
#include <influx/truevel>
#include <influx/zones_stage>
#include <influx/zones_checkpoint>
#include <influx/maprankings>
#include <influx/style_tas>


//#define DEBUG



float g_flJoin[INF_MAXPLAYERS];



ConVar g_ConVar_Title;
ConVar g_ConVar_TitleDisplayAlways;
ConVar g_ConVar_TabSize;
ConVar g_ConVar_TabAmount;
ConVar g_ConVar_Pos;
ConVar g_ConVar_Clr;

char g_szTitle[256];
float g_fPos[2];
int g_iClr[4];


// LIBRARIES
bool g_bLib_Hud;
bool g_bLib_Strafes;
bool g_bLib_Jumps;
bool g_bLib_Pause;
bool g_bLib_Practise;
bool g_bLib_Recording;
bool g_bLib_StrfSync;
bool g_bLib_Truevel;
bool g_bLib_Stage;
bool g_bLib_CP;
bool g_bLib_MapRanks;
bool g_bLib_Style_Tas;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - HUD Draw | CS:GO",
    description = "Displays info on player's screen.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    if ( GetEngineVersion() != Engine_CSGO )
    {
        FormatEx( szError, error_len, "This plugin is for CS:GO only. You can safely remove this plugin file." );
        return APLRes_SilentFailure;
    }
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    // CONVARS
    g_ConVar_Title = CreateConVar( "influx_hud_draw_title", "\tInflux Timer", "Title to be shown to all players.", FCVAR_NOTIFY );
    g_ConVar_Title.AddChangeHook( E_ConVarChanged_Title );
    g_ConVar_Title.GetString( g_szTitle, sizeof( g_szTitle ) );
    
    g_ConVar_TitleDisplayAlways = CreateConVar( "influx_hud_draw_titlealways", "0", "Do we always display the title when player is in start/has no run?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    g_ConVar_TabSize = CreateConVar( "influx_hud_draw_tabsize", "6", "Amount of characters a tab is. If you increase/decrease font size you need to tweak this.", FCVAR_NOTIFY, true, 1.0 );
    g_ConVar_TabAmount = CreateConVar( "influx_hud_draw_tabnum", "5", "Amount of tabs to insert between columns.", FCVAR_NOTIFY, true, 0.0 );
    
    g_ConVar_Pos = CreateConVar( "influx_hud_draw_pos", "0 0.4", "Set the position where the sidebar is drawn.", FCVAR_NOTIFY );
    g_ConVar_Pos.AddChangeHook( E_ConVarChanged_Pos );
    GetHudMsgPos();
    
    g_ConVar_Clr = CreateConVar( "influx_hud_draw_clr", "255 255 255 255", "Set the color of the hud msg.", FCVAR_NOTIFY );
    g_ConVar_Clr.AddChangeHook( E_ConVarChanged_Clr );
    GetHudMsgClr();
    
    AutoExecConfig( true, "hud_draw_csgo", "influx" );
    
    
    // LIBRARIES
    g_bLib_Hud = LibraryExists( INFLUX_LIB_HUD );
    g_bLib_Strafes = LibraryExists( INFLUX_LIB_STRAFES );
    g_bLib_Jumps = LibraryExists( INFLUX_LIB_JUMPS );
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
    g_bLib_Practise = LibraryExists( INFLUX_LIB_PRACTISE );
    g_bLib_Recording = LibraryExists( INFLUX_LIB_RECORDING );
    g_bLib_StrfSync = LibraryExists( INFLUX_LIB_STRFSYNC );
    g_bLib_Truevel = LibraryExists( INFLUX_LIB_TRUEVEL );
    g_bLib_Stage = LibraryExists( INFLUX_LIB_ZONES_STAGE );
    g_bLib_CP = LibraryExists( INFLUX_LIB_ZONES_CP );
    g_bLib_MapRanks = LibraryExists( INFLUX_LIB_MAPRANKS );
    g_bLib_Style_Tas = LibraryExists( INFLUX_LIB_STYLE_TAS );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_HUD ) ) g_bLib_Hud = true;
    if ( StrEqual( lib, INFLUX_LIB_STRAFES ) ) g_bLib_Strafes = true;
    if ( StrEqual( lib, INFLUX_LIB_JUMPS ) ) g_bLib_Jumps = true;
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = true;
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = true;
    if ( StrEqual( lib, INFLUX_LIB_RECORDING ) ) g_bLib_Recording = true;
    if ( StrEqual( lib, INFLUX_LIB_STRFSYNC ) ) g_bLib_StrfSync = true;
    if ( StrEqual( lib, INFLUX_LIB_TRUEVEL ) ) g_bLib_Truevel = true;
    if ( StrEqual( lib, INFLUX_LIB_ZONES_STAGE ) ) g_bLib_Stage = true;
    if ( StrEqual( lib, INFLUX_LIB_ZONES_CP ) ) g_bLib_CP = true;
    if ( StrEqual( lib, INFLUX_LIB_MAPRANKS ) ) g_bLib_MapRanks = true;
    if ( StrEqual( lib, INFLUX_LIB_STYLE_TAS ) ) g_bLib_Style_Tas = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_HUD ) ) g_bLib_Hud = false;
    if ( StrEqual( lib, INFLUX_LIB_STRAFES ) ) g_bLib_Strafes = false;
    if ( StrEqual( lib, INFLUX_LIB_JUMPS ) ) g_bLib_Jumps = false;
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = false;
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = false;
    if ( StrEqual( lib, INFLUX_LIB_RECORDING ) ) g_bLib_Recording = false;
    if ( StrEqual( lib, INFLUX_LIB_STRFSYNC ) ) g_bLib_StrfSync = false;
    if ( StrEqual( lib, INFLUX_LIB_TRUEVEL ) ) g_bLib_Truevel = false;
    if ( StrEqual( lib, INFLUX_LIB_ZONES_STAGE ) ) g_bLib_Stage = false;
    if ( StrEqual( lib, INFLUX_LIB_ZONES_CP ) ) g_bLib_CP = false;
    if ( StrEqual( lib, INFLUX_LIB_MAPRANKS ) ) g_bLib_MapRanks = false;
    if ( StrEqual( lib, INFLUX_LIB_STYLE_TAS ) ) g_bLib_Style_Tas = false;
}

public void OnClientPutInServer( int client )
{
    g_flJoin[client] = GetEngineTime();
}

public void E_ConVarChanged_Title( ConVar convar, const char[] oldValue, const char[] newValue )
{
    g_ConVar_Title.GetString( g_szTitle, sizeof( g_szTitle ) );
}

public void E_ConVarChanged_Pos( ConVar convar, const char[] oldValue, const char[] newValue )
{
    GetHudMsgPos();
}

public void E_ConVarChanged_Clr( ConVar convar, const char[] oldValue, const char[] newValue )
{
    GetHudMsgClr();
}

public Action Influx_OnDrawHUD( int client, int target, HudType_t hudtype )
{
    static char szMsg[256];
    szMsg[0] = 0;
    
    static char szTemp[64];
    static char szTemp2[64];
    static char szTemp3[64];
    
    decl String:szSecFormat[12];
    
    RunState_t state = Influx_GetClientState( target );
    
    decl curlinelen;
    
    bool bIsReplayBot = ( IsFakeClient( target ) && g_bLib_Recording && Influx_GetReplayBot() == target );
    
    
    int hideflags = ( g_bLib_Hud ) ? Influx_GetClientHideFlags( client ) : 0;
    
    
    if ( hudtype == HUDTYPE_TIMER )
    {
        int nTabAmount = g_ConVar_TabAmount.IntValue;
        
        
        Influx_GetSecondsFormat_Timer( szSecFormat, sizeof( szSecFormat ) );
        
        curlinelen = 0;
        
        
        if (state <= STATE_START
        &&  (g_ConVar_TitleDisplayAlways.BoolValue || (g_flJoin[client] + 15.0 > GetEngineTime())))
        {
            FormatEx( szMsg, sizeof( szMsg ), "%s", g_szTitle );
        }
        else if ( !bIsReplayBot )
        {
            if ( !(hideflags & HIDEFLAG_PB_TIME) && Influx_IsClientCached( target ) )
            {
                float time = Influx_GetClientCurrentPB( target );
                
                if ( time > INVALID_RUN_TIME )
                {
                    Inf_FormatSeconds( time, szTemp, sizeof( szTemp ), szSecFormat );
                    curlinelen = FormatEx( szMsg, sizeof( szMsg ), "PB: %s", szTemp );
                }
                else
                {
                    curlinelen = strcopy( szMsg, sizeof( szMsg ), "PB: N/A" );
                }
            }
            
            if ( state == STATE_RUNNING && g_bLib_StrfSync )
            {
                GetTabs( curlinelen, szTemp2, sizeof( szTemp2 ), nTabAmount );
                
                Format( szMsg, sizeof( szMsg ), "%s%sSync: %.1f﹪",
                    szMsg,
                    szTemp2,
                    Influx_GetClientStrafeSync( target ) );
            }
            else if ( !(hideflags & HIDEFLAG_WR_TIME) )
            {
                float time = Influx_GetClientCurrentBestTime( target );
                
                if ( time > INVALID_RUN_TIME )
                {
                    Inf_FormatSeconds( time, szTemp3, sizeof( szTemp3 ), szSecFormat );
                    Influx_GetClientCurrentBestName( target, szTemp2, sizeof( szTemp2 ) );
                    
                    LimitString( szTemp2, sizeof( szTemp2 ), 8 );
                    
                    
                    FormatEx( szTemp, sizeof( szTemp ), "SR: %s (%s)", szTemp3, szTemp2 );
                }
                else
                {
                    strcopy( szTemp, sizeof( szTemp ), "SR: N/A" );
                }
                
                GetTabs( curlinelen, szTemp2, sizeof( szTemp2 ), nTabAmount );
                
                Format( szMsg, sizeof( szMsg ), "%s%s%s",
                    szMsg,
                    szTemp2,
                    szTemp );
            }
        }
        
        
        AddAndGotoLine( szMsg, szMsg, sizeof( szMsg ), 2 );
        curlinelen = 0;
        /*
Influx_GetModeName( Influx_GetReplayMode(), szTemp, sizeof( szTemp ), true );
            Influx_GetStyleName( Influx_GetReplayStyle(), szTemp2, sizeof( szTemp2 ), true );
        */
        
        if ( bIsReplayBot )
        {
            Inf_FormatSeconds( Influx_GetReplayTime(), szTemp, sizeof( szTemp ), szSecFormat );
            
            curlinelen = FormatEx( szTemp2, sizeof( szTemp2 ), "Time: %s", szTemp );
            
            
            Format( szMsg, sizeof( szMsg ), "%s%s", szMsg, szTemp2 );
        }
        else if ( state == STATE_START )
        {
            Influx_GetRunName( Influx_GetClientRunId( target ), szTemp2, sizeof( szTemp2 ) );
            curlinelen = Format( szTemp2, sizeof( szTemp2 ), "In %s Start", szTemp2 );
            
            Format( szMsg, sizeof( szMsg ), "%s%s", szMsg, szTemp2 );
        }
        else if ( state >= STATE_RUNNING )
        {
            float time = INVALID_RUN_TIME;
            float cptime = INVALID_RUN_TIME;
            
            decl String:pre[2];
            pre[0] = 0;
            pre[1] = 0;
            
            
            decl String:szForm[32];
            strcopy( szForm, sizeof( szForm ), "%05.2f" );
            
            decl String:szTimeName[32];
            strcopy( szTimeName, sizeof( szTimeName ), "Time: " );
            
            decl String:szColor[32];
            szColor[0] = 0;
            
            
            
            if (g_bLib_CP
            &&  (GetEngineTime() - Influx_GetClientLastCPTouch( target )) < 2.0)
            {
                cptime = Influx_GetClientLastCPSRTime( target );
                
                // Fallback to best time if no SR time is found.
                if ( cptime == INVALID_RUN_TIME ) cptime = Influx_GetClientLastCPBestTime( target );
            }
            
            
            //if ( IsFakeClient( target ) )
            if ( state == STATE_FINISHED )
            {
                time = Influx_GetClientFinishedTime( target );
            }
            else if ( g_bLib_Pause && Influx_IsClientPaused( target ) )
            {
                time = Influx_GetClientPausedTime( target );
            }
            else if ( cptime != INVALID_RUN_TIME )
            {
                float lastcptime = Influx_GetClientLastCPTime( target );
                
                
                
                time = Inf_GetTimeDif( lastcptime, cptime, view_as<int>( pre[0] ) );
                strcopy( szForm, sizeof( szForm ), szSecFormat );
                
                strcopy( szColor, sizeof( szColor ), " color='#42f4a1'" );
                
                strcopy( szTimeName, sizeof( szTimeName ), "CP: " );
            }
            else if ( g_bLib_Style_Tas && Influx_GetClientStyle( target ) == STYLE_TAS )
            {
                time = Influx_GetClientTASTime( target );
                strcopy( szForm, sizeof( szForm ), szSecFormat );
            }
            else
            {
                time = Influx_GetClientTime( target );
                strcopy( szForm, sizeof( szForm ), szSecFormat );
                
                strcopy( szColor, sizeof( szColor ), " color='#42f4a1'" );
            }
            
            if ( time != INVALID_RUN_TIME )
            {
                curlinelen += strlen( pre );
                
                
                curlinelen += strlen( szTimeName );
                
                Inf_FormatSeconds( time, szTemp, sizeof( szTemp ), szForm );
                
                curlinelen += strlen( szTemp );
                
                Format( szMsg, sizeof( szMsg ), "%s%s%s%s",
                    szMsg,
                    szTimeName,
                    ( pre[0] != 0 ) ? pre : "",
                    szTemp );
            }
        }
        
        
        GetTabs( curlinelen, szTemp, sizeof( szTemp ), nTabAmount );
        
        Format( szMsg, sizeof( szMsg ), "%s%sSpeed: %03.0f",
            szMsg,
            szTemp,
            GetSpeed( target ) );
        
        AddAndGotoLine( szMsg, szMsg, sizeof( szMsg ), 3 );
        
        curlinelen = 0;
        
        
        if ( !IsFakeClient( target ) )
        {
            if ( g_bLib_MapRanks )
            {
                int rank = Influx_GetClientCurrentMapRank( target );
                int numrecs = Influx_GetClientCurrentMapRankCount( target );
                
                if ( numrecs > 0 )
                {
                    if ( rank > 0 )
                    {
                        curlinelen = FormatEx( szTemp, sizeof( szTemp ), "Rank: %i/%i", rank, numrecs );
                    }
                    else
                    {
                        curlinelen = FormatEx( szTemp, sizeof( szTemp ), "Rank: -/%i", numrecs );
                    }
                }
                else
                {
                    curlinelen = FormatEx( szTemp, sizeof( szTemp ), "Rank: -/-" );
                }
                
                Format( szMsg, sizeof( szMsg ), "%s%s", szMsg, szTemp );
            }
        }
        else if ( bIsReplayBot )
        {
            Influx_GetReplayName( szTemp, sizeof( szTemp ) );
            
            LimitString( szTemp, sizeof( szTemp ), 8 );
            
            FormatEx( szTemp2, sizeof( szTemp2 ), "Name: %s", szTemp );
            
            AddPadding( szTemp2, sizeof( szTemp2 ), 12 );
            
            curlinelen = strlen( szTemp2 );
            
            Format( szMsg, sizeof( szMsg ), "%s%s", szMsg, szTemp2 );
        }
        
        
        int targetmode = MODE_INVALID;
        int targetstyle = STYLE_INVALID;
        
        if ( bIsReplayBot )
        {
            targetmode = Influx_GetReplayMode();
            targetstyle = Influx_GetReplayStyle();
        }
        else
        {
            targetmode = Influx_GetClientMode( target );
            targetstyle = Influx_GetClientStyle( target );
        }
        
        
        Influx_GetModeShortName( targetmode, szTemp3, sizeof( szTemp3 ), true );
        Influx_GetStyleShortName( targetstyle, szTemp2, sizeof( szTemp2 ), true );
        
        if ( szTemp2[0] == 0 && szTemp3[0] == 0 )
        {
            strcopy( szTemp2, sizeof( szTemp2 ), "N/A" );
        }
        
        GetTabs( curlinelen, szTemp, sizeof( szTemp ), nTabAmount );
        
        Format( szMsg, sizeof( szMsg ), "%s%sStyle: %s%s%s",
            szMsg,
            szTemp,
            szTemp2,
            ( szTemp2[0] != 0 ) ? " " : "",
            szTemp3 );
        
        
        
        if ( szMsg[0] != 0 )
        {
            PrintHintText( client, szMsg );
        }
    }
    else if ( hudtype == HUDTYPE_HUDMSG )
    {
        Influx_GetSecondsFormat_Sidebar( szSecFormat, sizeof( szSecFormat ) );
        
        
        // Disable for bots.
        if ( IsFakeClient( target ) )
        {
            return Plugin_Stop;
        }
        
        
        if ( g_bLib_Stage && Influx_ShouldDisplayStages( target ) )
        {
            int stages = Influx_GetClientStageCount( target );
            
            if ( stages < 2 )
            {
                strcopy( szTemp2, sizeof( szTemp2 ), "Linear" );
            }
            else
            {
                FormatEx( szTemp2, sizeof( szTemp2 ), "%i/%i", Influx_GetClientStage( target ), stages );
            }
            
            FormatEx( szMsg, sizeof( szMsg ), "Stage: %s", szTemp2 );
        }
        
        ADD_SEPARATOR( szMsg, "\n " );
        
        if ( g_bLib_Strafes && state >= STATE_RUNNING && Influx_IsCountingStrafes( target ) )
        {
            Format( szMsg, sizeof( szMsg ), "%s%sStrafes: %i",
                szMsg,
                NEWLINE_CHECK( szMsg ),
                Influx_GetClientStrafeCount( target ) );
        }
        
        if ( g_bLib_Jumps && state >= STATE_RUNNING && Influx_IsCountingJumps( target ) )
        {
            Format( szMsg, sizeof( szMsg ), "%s%sJumps: %i",
                szMsg,
                NEWLINE_CHECK( szMsg ),
                Influx_GetClientJumpCount( target ) );
        }
        
        
        ADD_SEPARATOR( szMsg, "\n " );
        
        bool bprac = ( g_bLib_Practise && !(hideflags & HIDEFLAG_PRACMODE) && Influx_IsClientPractising( target ) );
        
        bool bpause = ( g_bLib_Pause && !(hideflags & HIDEFLAG_PAUSEMODE) && Influx_IsClientPaused( target ) );
        
        if ( bprac || bpause )
        {
            if ( bprac )
            {
                Format( szMsg, sizeof( szMsg ), "%sPractising", szMsg );
            }
            
            if ( bpause )
            {
                Format( szMsg, sizeof( szMsg ), "%s%sPaused", szMsg, bprac ? "/" : "" );
            }
        }
        
        
        DisplayHudMsg( client, szMsg );
    }
    
    return Plugin_Stop;
}

// Check if they want truevel.
stock float GetSpeed( int client )
{
    return ( g_bLib_Truevel && Influx_IsClientUsingTruevel( client ) ) ? GetEntityTrueSpeed( client ) : GetEntitySpeed( client );
}

/*stock void ShowPanel( int client, const char[] msg )
{
    Panel panel = new Panel();
    panel.SetTitle( msg );
    panel.Send( client, Hndlr_Panel_Empty, 3 );
    
    delete panel;
}*/

public int Hndlr_Panel_Empty( Menu menu, MenuAction action, int client, int param2 ) {}


stock bool AddAndGotoLine( const char[] sz, char[] out, int len, int wantedline )
{
    if ( wantedline < 2 ) return false;
    
    
    int numlines = 1;
    
    int start = 0;
    decl pos;
    while ( (pos = FindCharInString( sz[start], '\n' )) != -1 )
    {
        ++numlines;
        
        start += pos + 1;
    }
    
    if ( numlines >= wantedline ) return false;
    
    
    while ( numlines < wantedline )
    {
        int lastpos = strlen( out ) - 1;
        
        if ( lastpos < 0 ) lastpos = 0;
        
        Format( out, len, "%s%s\n", out, (lastpos == 0 || out[lastpos] == '\n') ? " " : "" );
        
        ++numlines;
    }
    
    return true; 
}

stock void DisplayHudMsg( int client, const char[] msg )
{
    int clients[1];
    clients[0] = client;
    
    //float pos[2];
    //pos = view_as<float>( { 1.0, 0.0 } );
    
    SendHudMsg( clients, 1, msg, 2, g_fPos, g_iClr, g_iClr, 0, 0.0, 0.0, 1.0, 0.0 );
}

stock void SendHudMsg(  int[] clients,
                        int nClients,
                        const char[] text,
                        int channel,
                        const float pos[2],
                        const int clr1[4],
                        const int clr2[4],
                        int effect,
                        float fade_in,
                        float fade_out,
                        float hold_time,
                        float fx_time )
{
    static UserMsg UserMsg_HudMsg = INVALID_MESSAGE_ID;
    
    if ( UserMsg_HudMsg == INVALID_MESSAGE_ID )
    {
        if ( (UserMsg_HudMsg = GetUserMessageId( "HudMsg" )) == INVALID_MESSAGE_ID )
        {
            SetFailState( INF_CON_PRE..."Couldn't find usermessage id for HudMsg!" );
        }
    }
    
    
    Handle hMsg = StartMessageEx( UserMsg_HudMsg, clients, nClients, USERMSG_BLOCKHOOKS );
    
    if ( hMsg != null )
    {
        if ( GetUserMessageType() == UM_Protobuf )
        {
            PbSetInt( hMsg, "channel", channel );
            PbSetVector2D( hMsg, "pos", pos );
            PbSetColor( hMsg, "clr1", clr1 );
            PbSetColor( hMsg, "clr2", clr2 );
            PbSetInt( hMsg, "effect", effect );
            PbSetFloat( hMsg, "fade_in_time", fade_in );
            PbSetFloat( hMsg, "fade_out_time", fade_out );
            PbSetFloat( hMsg, "hold_time", hold_time );
            PbSetFloat( hMsg, "fx_time", fx_time );
            PbSetString( hMsg, "text", text );
        }
        else
        {
            PrintToServer( "This shouldn't happen!" );
        }
        
        EndMessage();
    }
}

stock void GetTabs( int linelen, char[] out, int len, int numtabs = 3 )
{
    out[0] = 0;
    
    int num = numtabs - RoundToFloor( linelen / g_ConVar_TabSize.FloatValue );

    for ( int i = 0; i < num; i++ )
    {
        Format( out, len, "%s\t", out );
    }
}

stock void AddPadding( char[] out, int len, int padding )
{
    int l = strlen( out );
    
    if ( l >= padding ) return;
    
    if ( padding >= len ) return;
    
    
    for ( int i = l; i < padding; i++ )
    {
        out[i] = ' ';
    }
    
    out[padding] = 0;
}

stock void GetHudMsgPos()
{
    decl String:sz[32];
    decl String:bufs[2][16];
    g_ConVar_Pos.GetString( sz, sizeof( sz ) );
    
    ExplodeString( sz, " ", bufs, sizeof( bufs ), sizeof( bufs[] ), true );
    
    g_fPos[0] = StringToFloat( bufs[0] );
    g_fPos[1] = StringToFloat( bufs[1] );
}

stock void GetHudMsgClr()
{
    decl String:sz[32];
    decl String:bufs[sizeof( g_iClr )][8];
    g_ConVar_Clr.GetString( sz, sizeof( sz ) );
    
    ExplodeString( sz, " ", bufs, sizeof( bufs ), sizeof( bufs[] ), true );
    
    for ( int i = 0; i < sizeof( g_iClr ); i++ )
    {
        g_iClr[i] = StringToInt( bufs[i] );
    }
}