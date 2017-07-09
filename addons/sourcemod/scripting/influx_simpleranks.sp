#include <sourcemod>


#include <influx/core>
#include <influx/simpleranks>

#include <msharedutil/misc>


#undef REQUIRE_PLUGIN
#include <influx/help>



#define DEBUG



#define INF_PRIVCOM_CUSTOMRANK          "sm_inf_customrank"
#define INF_PRIVCOM_MAPREWARD           "sm_inf_setmapreward"

#define INF_TABLE_SIMPLERANKS           "inf_simpleranks"
#define INF_TABLE_SIMPLERANKS_HISTORY   "inf_simpleranks_history"
#define INF_TABLE_SIMPLERANKS_MAPS      "inf_simpleranks_maps"


#define RANK_FILE_NAME                  "influx_simpleranks.cfg"


#define MAX_RANK_SIZE                   128
#define MAX_RANK_SIZE_CELL              ( MAX_RANK_SIZE / 4 )

enum
{
    RANK_NAME[MAX_RANK_SIZE_CELL] = 0,
    
    RANK_POINTS,
    RANK_UNLOCK,
    
    RANK_SIZE
};

enum
{
    REWARD_RUN_ID = 0,
    
    REWARD_POINTS,
    
    REWARD_SIZE
};



int g_nPoints[INF_MAXPLAYERS];
char g_szCurRank[INF_MAXPLAYERS][MAX_RANK_SIZE];
int g_iCurRank[INF_MAXPLAYERS];
bool g_bChose[INF_MAXPLAYERS];


ArrayList g_hMapRewards;
//int g_nMapReward;


// CONVARS
ConVar g_ConVar_DefMapReward;
ConVar g_ConVar_NotifyReward;
ConVar g_ConVar_NotifyNewRank;


ArrayList g_hRanks;

bool g_bLate;


#include "influx_simpleranks/cmds.sp"
#include "influx_simpleranks/db.sp"
#include "influx_simpleranks/menus.sp"

public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Simple Ranks",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_SIMPLERANKS );
    
    
    CreateNative( "Influx_GetClientSimpleRank", Native_GetClientSimpleRank );
    CreateNative( "Influx_GetClientSimpleRankPoints", Native_GetClientSimpleRankPoints );
    
    
    g_bLate = late;
}

public void OnPluginStart()
{
    g_hRanks = new ArrayList( RANK_SIZE );
    
    g_hMapRewards = new ArrayList( REWARD_SIZE );
    //g_nMapReward = -1;
    
    
    // PRIVILEGE CMDS
    RegAdminCmd( INF_PRIVCOM_CUSTOMRANK, Cmd_Empty, ADMFLAG_ROOT );
    RegAdminCmd( INF_PRIVCOM_MAPREWARD, Cmd_Empty, ADMFLAG_ROOT );
    
    
    // ADMIN CMDS
    //RegAdminCmd( "sm_recalcranks", Cmd_Admin_RecalcRanks, ADMFLAG_ROOT );
    
    
    // CMDS
    RegConsoleCmd( "sm_rankmenu", Cmd_Menu_Rank );
    RegConsoleCmd( "sm_customrank", Cmd_CustomRank );
    RegConsoleCmd( "sm_setmapreward", Cmd_SetMapReward );
    
    
    // CONVARS
    g_ConVar_DefMapReward = CreateConVar( "influx_simpleranks_defmapreward", "3", "Default map reward.", FCVAR_NOTIFY, true, 0.0 );
    g_ConVar_NotifyReward = CreateConVar( "influx_simpleranks_displayreward", "1", "Do we notify the player with the amount of points they get?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_NotifyNewRank = CreateConVar( "influx_simpleranks_displaynewrank", "1", "Do we notify the player with the new rank they receive?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    AutoExecConfig( true, "simpleranks", "influx" );
    
    
    if ( g_bLate )
    {
        int mapid = Influx_GetCurrentMapId();
        
        if ( mapid > 0 )
            Influx_OnMapIdRetrieved( mapid, false );
        
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( !IsClientInGame( i ) ) continue;
            
            
            OnClientPutInServer( i );
            
            if ( !IsFakeClient( i ) )
            {
                int uid = Influx_GetClientId( i );
            
                if ( uid > 0 )
                    Influx_OnClientIdRetrieved( i, uid, false );
            }
        }
    }
}

public void OnMapStart()
{
    ReadRanks();
}

public void OnClientPutInServer( int client )
{
    g_nPoints[client] = 0;
    g_szCurRank[client][0] = 0;
    g_iCurRank[client] = -1;
    
    g_bChose[client] = false;
}

public void OnAllPluginsLoaded()
{
    DB_Init();
}

stock void ReadRanks()
{
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Reading ranks from file... (%s)", RANK_FILE_NAME );
#endif

    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "configs/"...RANK_FILE_NAME );

    KeyValues kv = new KeyValues( "Ranks" );
    kv.ImportFromFile( szPath );
    
    if ( !kv.GotoFirstSubKey() )
    {
        delete kv;
        return;
    }
    
    
    g_hRanks.Clear();
    
    
    decl String:szTemp[256];
    decl data[RANK_SIZE];
    
    do
    {
        if ( !kv.GetSectionName( szTemp, sizeof( szTemp ) ) )
        {
            LogError( INF_CON_PRE..."Couldn't read rank name!" );
            continue;
        }
        
        if ( strlen( szTemp ) >= MAX_RANK_SIZE )
        {
            LogError( INF_CON_PRE..."Rank name length cannot exceed %i characters! (%s)", MAX_RANK_SIZE, szTemp );
            continue;
        }
        
        strcopy( view_as<char>( data[RANK_NAME] ), MAX_RANK_SIZE, szTemp );
        
        
        int points = kv.GetNum( "points", -1 );
        
        if ( points < 0 )
        {
            LogError( INF_CON_PRE..."Invalid rank points %i! Must be above or equal to 0! (%s)", points, data[RANK_NAME] );
            continue;
        }
        
        
        data[RANK_POINTS] = points;
        data[RANK_UNLOCK] = kv.GetNum( "unlock", 0 );
        
        
        g_hRanks.PushArray( data );
    }
    while ( kv.GotoNextKey() );
}

public void Influx_OnRequestHelpCmds()
{
    Influx_AddHelpCommand( "sm_rankmenu", "Choose your chat rank." );
    Influx_AddHelpCommand( "sm_customrank", "Ability to set your own custom rank. (Flag access)" );
    Influx_AddHelpCommand( "sm_setmapreward <name (optional)> <reward>", "Set map's reward.", true );
}

public void Influx_OnMapIdRetrieved( int mapid, bool bNew )
{
    DB_InitMap( mapid );
}

public void Influx_OnClientIdRetrieved( int client, int uid, bool bNew )
{
    DB_InitClient( client );
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    // TODO: Add multiple runs with custom reward amounts.
    if ( runid != 1 ) return;
    
    
    DB_CheckClientRecCount( client, runid, mode, style );
}

stock int GetRankClosest( int points, bool bIgnoreUnlock = true )
{
    int closest_index = -1;
    
    decl closest_dif;
    
    decl p;
    decl dif;
    
    int len = g_hRanks.Length;
    for ( int i = 0; i < len; i++ )
    {
        p = g_hRanks.Get( i, RANK_POINTS );
        
        if ( bIgnoreUnlock && g_hRanks.Get( i, RANK_UNLOCK ) ) continue;
        
        if ( p > points ) continue;
        
        
        dif = points - p;
        
        if ( closest_index != -1 && closest_dif < dif )
        {
            continue;
        }
        
        closest_index = i;
        closest_dif = dif;
    }
    
    return closest_index;
}

stock int FindRankByName( const char[] szName )
{
    decl String:szTemp[MAX_RANK_SIZE];
    
    int len = g_hRanks.Length;
    for ( int i = 0; i < len; i++ )
    {
        g_hRanks.GetString( i, szTemp, sizeof( szTemp ) );
        
        if ( StrEqual( szName, szTemp ) )
        {
            return i;
        }
    }
    
    return -1;
}

stock int GetRankPoints( int index )
{
    if ( index == -1 ) return 133700;
    
    return g_hRanks.Get( index, RANK_POINTS );
}

stock void GetRankName( int index, char[] out, int len )
{
    if ( index == -1 ) return;
    
    
    g_hRanks.GetString( index, out, len );
}

stock void SetClientDefRank( int client )
{
    decl index;
    
    index = GetRankClosest( g_nPoints[client] );
    if ( index == -1 )
    {
        index = GetRankClosest( g_nPoints[client], false );
        if ( index == -1 ) return;
    }
    

    SetClientRank( client, index, false );
}

stock void SetClientRank( int client, int index, bool bChose, const char[] szOver = "", bool bPrint = false )
{
    if ( szOver[0] != 0 )
    {
        strcopy( g_szCurRank[client], sizeof( g_szCurRank[] ), szOver );
    }
    else
    {
        GetRankName( index, g_szCurRank[client], sizeof( g_szCurRank[] ) );
    }
    
    
    g_bChose[client] = bChose;
    
    g_iCurRank[client] = index;
    
    
    if ( bPrint )
    {
        Influx_PrintToChat( _, client, "Your rank is now '{MAINCLR1}%s{CHATCLR}'!", g_szCurRank[client] );
    }
}

stock void RewardClient( int client, int runid, bool bPrintReward, bool bPrintNewRank, int override_reward = -1 )
{
    int reward;
    
    if ( override_reward < 0 )
    {
        reward = GetMapRewardPointsSafe( runid );
    }
    else
    {
        // Use override reward.
        reward = override_reward;
    }
    
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Rewarding client %i with %i points!",
        client,
        reward );
#endif
    
    // Nothing to update!
    if ( reward <= 0 ) return;
    
    
    int oldrank = GetRankClosest( g_nPoints[client] );
    int newrank = GetRankClosest( g_nPoints[client] + reward );
    
    g_nPoints[client] += reward;
    
    
    if ( bPrintReward )
    {
        Influx_PrintToChat( _, client, "You've received {MAINCLR1}%i{CHATCLR} points! You now have {MAINCLR1}%i{CHATCLR} points!", reward, g_nPoints[client] );
    }
    
    if ( oldrank != newrank && newrank != -1 )
    {
        decl String:szNewRank[MAX_RANK_SIZE];
        GetRankName( newrank, szNewRank, sizeof( szNewRank ) );
        
        if ( bPrintNewRank )
        {
            Influx_PrintToChat( _, client, "You are now {MAINCLR1}%s{CHATCLR}!", szNewRank );
        }
        
        // Update their rank.
        if ( !g_bChose[client] )
        {
            SetClientRank( client, newrank, false, szNewRank );
        }
    }
    
    DB_IncClientPoints( client, runid, reward );
}

stock bool IsValidReward( int reward, int issuer = 0, bool bPrint = false )
{
    if ( reward < 0 )
    {
        if ( bPrint )
        {
            Inf_ReplyToClient( issuer, "Reward cannot be negative!" );
        }
        
        return false;
    }
    
    return true;
}

stock void SetCurrentMapReward( int issuer, int runid, int reward )
{
    if ( !IsValidReward( reward, issuer, true ) ) return;
    
    
    AddMapReward( runid, reward );
    
    DB_UpdateMapReward( Influx_GetCurrentMapId(), runid, reward );
    
    
    Inf_ReplyToClient( issuer, "Set current map reward to {MAINCLR1}%i{CHATCLR} points.", reward );
}

stock bool CanUserUseCustomRank( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_CUSTOMRANK, ADMFLAG_ROOT );
}

stock bool CanUserSetMapReward( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_MAPREWARD, ADMFLAG_ROOT );
}

stock int AddMapReward( int runid, int points )
{
    int index = FindMapRewardById( runid );
    if ( index != -1 ) return index;
    
    
    decl data[REWARD_SIZE];
    
    data[REWARD_RUN_ID] = runid;
    data[REWARD_POINTS] = points;
    
    
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Added custom map rewards (runid: %i | points: %i)",
        data[REWARD_RUN_ID],
        data[REWARD_POINTS] );
#endif
    
    return g_hMapRewards.PushArray( data );
}

stock int FindMapRewardById( int runid )
{
    int len = g_hMapRewards.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hMapRewards.Get( i, REWARD_RUN_ID ) == runid )
        {
            return i;
        }
    }
    
    return -1;
}

stock int GetMapRewardPointsSafe( int runid )
{
    int reward = GetMapRewardPoints( runid )
    
    return ( reward < 0 ) ? g_ConVar_DefMapReward.IntValue : reward;
}

stock int GetMapRewardPoints( int runid )
{
    int index = FindMapRewardById( runid );
    
    if ( index == -1 ) return -1;
    
    
    return g_hMapRewards.Get( index, REWARD_POINTS );
}

// NATIVES
public int Native_GetClientSimpleRank( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    SetNativeString( 2, g_szCurRank[client], GetNativeCell( 3 ) );
    
    return 1;
}

public int Native_GetClientSimpleRankPoints( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return g_nPoints[client];
}