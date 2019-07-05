#include <sourcemod>

#include <influx/core>

#undef REQUIRE_PLUGIN
#include <influx/hud>


ConVar g_ConVar_MinTime;
ConVar g_ConVar_NumDecimals;

bool g_bLib_Hud;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Chat Records",
    description = "Displays records in chat.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // PHRASES
    LoadTranslations( INFLUX_PHRASES );
    
    
    // CONVARS
    g_ConVar_MinTime = CreateConVar( "influx_recchat_mintimeformsg", "10", "If record is shorter than this, don't do a chat message.", FCVAR_NOTIFY );
    g_ConVar_NumDecimals = CreateConVar( "influx_recchat_numdecimals", "2", "Number of decimals to use when printing to chat.", FCVAR_NOTIFY, true, 0.0, true, 3.0 );
    
    
    AutoExecConfig( true, "recchat", "influx" );
    
    
    // LIBRARIES
    g_bLib_Hud = LibraryExists( INFLUX_LIB_HUD );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_HUD ) ) g_bLib_Hud = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_HUD ) ) g_bLib_Hud = false;
}

public void Influx_OnRequestResultFlags()
{
    Influx_AddResultFlag( "Don't print record chat message", RES_CHAT_DONTPRINT );
}

stock bool ShouldPrint( float time, int flags )
{
    // We don't want to print for this run.
    if ( flags & RES_CHAT_DONTPRINT ) return false;
    
    
    // Let them see best records always!
    if ( flags & (RES_TIME_ISBEST | RES_TIME_FIRSTREC) ) return true;
    
    
    // Must be more than this.
    return ( time > g_ConVar_MinTime.FloatValue );
}

stock bool CanPrintToClient( int client, int finisher, int flags )
{
    int hideflags = Influx_GetClientHideFlags( client );
    
    // Allow my own sounds.
    if ( client == finisher )
    {
        return ( hideflags & HIDEFLAG_CHAT_PERSONAL ) ? false : true;
    }
    
    // Allow best sounds.
    if ( flags & (RES_TIME_ISBEST | RES_TIME_FIRSTREC) ) 
    {
        return ( hideflags & HIDEFLAG_CHAT_BEST ) ? false : true;
    }
    
    return ( hideflags & HIDEFLAG_CHAT_NORMAL ) ? false : true;
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    if ( !ShouldPrint( time, flags ) ) return;
    
    
    int nClients = 0;
    int[] clients = new int[MaxClients];
    
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame( i ) && !IsFakeClient( i ) )
        {
            if ( g_bLib_Hud )
            {
                if ( !CanPrintToClient( i, client, flags ) ) continue;
            }
            
            clients[nClients++] = i;
        }
    }
    
    if ( !nClients ) return;
    
    
    bool isbest = ( flags & RES_TIME_ISBEST ) ? true : false;
    
    // Format our second formatting string.
    decl String:szFormSec[10];
    Inf_DecimalFormat( g_ConVar_NumDecimals.IntValue, szFormSec, sizeof( szFormSec ) );
    
    
    decl String:szName[MAX_NAME_LENGTH];
    decl String:szForm[10];
    decl String:szRun[MAX_RUN_NAME];
    decl String:szMode[64];
    decl String:szStyle[64];
    decl String:szRec[64];
    decl String:szImprove[64];
    
    if ( prev_best != INVALID_RUN_TIME )
    {
        int c;
        
        Inf_FormatSeconds( Inf_GetTimeDif( time, prev_best, c ), szForm, sizeof( szForm ), szFormSec );
        
        FormatEx( szRec, sizeof( szRec ), " {CHATCLR}({%s}%c%s{CHATCLR})",
            isbest ? "GREEN" : "LIGHTRED", // Is new best?
            c,
            szForm );
    }
    else
    {
        szRec[0] = '\0';
    }
    
    if ( time < prev_pb )
    {
        // Display more decimals if time is smaller than our formatting.
        decl String:sec[12];
        
        float dif = prev_pb - time;
        
        
        FormatEx( sec, sizeof( sec ), ( dif < 0.1 ) ? "%.3f" : "%.1f", dif );
        
        FormatEx( szImprove, sizeof( szImprove ), "%T", "INF_RUNFINISHEDPRINT_IMPROVEDBY", LANG_SERVER, sec );
    }
    else
    {
        szImprove[0] = '\0';
    }
    
    Inf_FormatSeconds( time, szForm, sizeof( szForm ), szFormSec );
    
    if ( Influx_ShouldModeDisplay( mode ) )
    {
        Influx_GetModeShortName( mode, szMode, sizeof( szMode ) );
        Format( szMode, sizeof( szMode ), " {GREY}[{PINK}%s{GREY}]", szMode );
    }
    else
    {
        szMode[0] = '\0';
    }
    
    
    if ( Influx_ShouldStyleDisplay( style ) )
    {
        Influx_GetStyleShortName( style, szStyle, sizeof( szStyle ) );
        Format( szStyle, sizeof( szStyle ), " [{PINK}%s{GREY}]", szStyle ); // {CHATCLR}
    }
    else
    {
        szStyle[0] = '\0';
    }
    
    
    
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    
    
    GetClientName( client, szName, sizeof( szName ) );
    Influx_RemoveChatColors( szName, sizeof( szName ) );
    
    // Use the influx phrases file to modify this.
    Influx_PrintToChatEx( _, client, clients, nClients, "%T",
        "INF_RUNFINISHEDPRINT", LANG_SERVER,
        szName,
        szRun,
        szForm,
        szRec,
        szImprove,
        szMode,
        szStyle );
}