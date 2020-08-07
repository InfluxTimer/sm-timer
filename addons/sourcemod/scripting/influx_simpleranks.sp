#include <sourcemod>


#include <influx/core>
#include <influx/simpleranks>

#include <msharedutil/misc>


#undef REQUIRE_PLUGIN
#include <influx/help>


// Uncomment this to test out SQL performance on map start.
//#define DISABLE_CREATE_SQL_TABLES             bool _bUseless = true; if ( _bUseless ) return;


//#define DEBUG



#define INF_PRIVCOM_CUSTOMRANK          "sm_inf_customrank"
#define INF_PRIVCOM_MAPREWARD           "sm_inf_setmapreward"

#define INF_TABLE_SIMPLERANKS           "inf_simpleranks"
#define INF_TABLE_SIMPLERANKS_HISTORY   "inf_simpleranks_history"
#define INF_TABLE_SIMPLERANKS_MAPS      "inf_simpleranks_maps"


#define RANK_FILE_NAME                  "influx_simpleranks.cfg"
#define RANK_MODEPOINTFILE_NAME         "influx_simpleranks_mode_points.cfg"
#define RANK_STYLEPOINTFILE_NAME        "influx_simpleranks_style_points.cfg"


#define MAX_RANK_SIZE                   128
#define MAX_RANK_SIZE_CELL              ( MAX_RANK_SIZE / 4 )

enum struct Rank_t
{
    char szRank[MAX_RANK_SIZE];

    int nPoints;
    int bUnlock;

    int fAdminFlags;
}

enum struct Reward_t
{
    int iRunId;
    int nPoints;
}


#define MAX_P_NAME_ID       32
#define MAX_P_NAME_ID_CELL  ( MAX_P_NAME_ID / 4 )

enum struct ModeNStyleReward_t
{
    char szSafeName[MAX_P_NAME_ID];
    int iId;

    int nPoints;
}



ArrayList g_hModePoints;
ArrayList g_hStylePoints;


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
ConVar g_ConVar_NotFirst;
ConVar g_ConVar_TopRankNumToPrint;
ConVar g_ConVar_UseClanTag;


ArrayList g_hRanks;

bool g_bLate;


#include "influx_simpleranks/cmds.sp"
#include "influx_simpleranks/db.sp"
#include "influx_simpleranks/db_cb.sp"
#include "influx_simpleranks/file.sp"
#include "influx_simpleranks/menus.sp"
#include "influx_simpleranks/menus_hndlrs.sp"

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
    CreateNative( "Influx_AddClientSimpleRankPoints", Native_AddClientSimpleRankPoints );
    
    
    g_bLate = late;
}

public void OnPluginStart()
{
    g_hRanks = new ArrayList( sizeof( Rank_t ) );
    
    g_hMapRewards = new ArrayList( sizeof( Reward_t ) );
    
    g_hModePoints = new ArrayList( sizeof( ModeNStyleReward_t ) );
    g_hStylePoints = new ArrayList( sizeof( ModeNStyleReward_t ) );
    //g_nMapReward = -1;
    
    
    // PHRASES
    LoadTranslations( INFLUX_PHRASES );
    
    
    // PRIVILEGE CMDS
    RegAdminCmd( INF_PRIVCOM_CUSTOMRANK, Cmd_Empty, ADMFLAG_ROOT );
    RegAdminCmd( INF_PRIVCOM_MAPREWARD, Cmd_Empty, ADMFLAG_ROOT );
    
    
    // ADMIN CMDS
    //RegAdminCmd( "sm_recalcranks", Cmd_Admin_RecalcRanks, ADMFLAG_ROOT );
    
    
    // CMDS
    RegConsoleCmd( "sm_rankmenu", Cmd_Menu_Rank );
    RegConsoleCmd( "sm_customrank", Cmd_CustomRank );
    RegConsoleCmd( "sm_setmapreward", Cmd_SetMapReward );
    RegConsoleCmd( "sm_givesimplepoints", Cmd_GivePoints );
    
    RegConsoleCmd( "sm_toprank", Cmd_Menu_TopRank );
    
    
    // CONVARS
    g_ConVar_DefMapReward = CreateConVar( "influx_simpleranks_defmapreward", "8", "Default map reward.", FCVAR_NOTIFY, true, 0.0 );
    g_ConVar_NotifyReward = CreateConVar( "influx_simpleranks_displayreward", "1", "Do we notify the player with the amount of points they get?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_NotifyNewRank = CreateConVar( "influx_simpleranks_displaynewrank", "1", "Do we notify the player with the new rank they receive?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_NotFirst = CreateConVar( "influx_simpleranks_reward_notfirst_perc", "0.1", "Percentage of the normal amount we give to players. 0 = Disable", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_TopRankNumToPrint = CreateConVar( "influx_simpleranks_toprank_printnum", "10", "How many ranks to print with !toprank command. 0 = Disable", FCVAR_NOTIFY, true, 0.0, true, 25.0 );
    g_ConVar_UseClanTag = CreateConVar( "influx_simpleranks_useclantag", "1", "Is player's clan tag replaced with their rank?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
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
    ReadStyleModePoints();

    CreateTimer( 1.0, T_CheckClanTags, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT );
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

public void Influx_OnRequestHelpCmds()
{
    Influx_AddHelpCommand( "rankmenu", "Choose your chat rank." );
    Influx_AddHelpCommand( "customrank", "Ability to set your own custom rank. (Flag access)" );
    Influx_AddHelpCommand( "toprank", "Show top ranks." );
    Influx_AddHelpCommand( "setmapreward <name (optional)> <reward>", "Set map's reward.", true );
    Influx_AddHelpCommand( "givesimplepoints <target (optional)> <reward>", "Give points to target.", true );
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
    // We don't get saved to db.
    if ( flags & RES_TIME_DONTSAVE ) return;
    

    if ( GetMapRewardPointsSafe( runid ) == 0 )
    {
        return;
    }
    
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
        p = g_hRanks.Get( i, Rank_t::nPoints );
        
        if ( bIgnoreUnlock && g_hRanks.Get( i, Rank_t::bUnlock ) ) continue;
        
        if ( GetRankFlags( i ) != 0 ) continue;
        
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

stock bool CanUseRankFlags( int client, const Rank_t rank )
{
    return ( rank.fAdminFlags == 0 || CheckCommandAccess( client, "", rank.fAdminFlags, true ) );
}

stock bool CanUseRankByIndex( int client, int index )
{
    if ( index == -1 ) return false;
    
    Rank_t rank;
    g_hRanks.GetArray( index, rank );
    
    return CanUseRank( client, rank );
}

stock bool CanUseRank( int client, const Rank_t rank )
{
    if ( g_nPoints[client] < rank.nPoints )
        return false;
    
    
    return CanUseRankFlags( client, rank );
}

stock bool ShouldDisplayRankByIndex( int client, int index )
{
    if ( index == -1 ) return false;
    
    
    Rank_t rank;
    g_hRanks.GetArray( index, rank );
    
    return CanUseRankFlags( client, rank );
}

stock bool ShouldDisplayRank( int client, const Rank_t rank )
{
    return CanUseRankFlags( client, rank );
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
    
    return g_hRanks.Get( index, Rank_t::nPoints );
}

stock void GetRankName( int index, char[] out, int len )
{
    if ( index == -1 ) return;
    
    
    g_hRanks.GetString( index, out, len );
}

stock int GetRankFlags( int index )
{
    if ( index == -1 ) return 0;
    
    return g_hRanks.Get( index, Rank_t::fAdminFlags );
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
    
    
    UpdateClientClanTag( client );
    
    
    if ( bPrint )
    {
        Influx_PrintToChat( _, client, "%T", "INF_RANKISNOW", client, g_szCurRank[client] );
    }
}

stock void RewardClient(int client,
                        int runid,
                        int mode,
                        int style,
                        int override_reward = -1,
                        bool bFirst = true,
                        bool bAdjustOld = false)
{
    int reward;
    
    if ( override_reward < 0 )
    {
        reward = CalcReward( runid, mode, style, bFirst );
    }
    else
    {
        // Use override reward.
        reward = override_reward;
    }
    
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Rewarding client %i with %i points! (First: %i | Override reward: %i)",
        client,
        reward,
        bFirst,
        override_reward );
#endif
    
    // Nothing to update!
    if ( reward <= 0 ) return;
    
    
    IncClientPoints( client, reward );
    
    DB_IncClientPoints( client, runid, mode, style, reward, bFirst, bAdjustOld );
}

stock bool IncClientPoints( int client, int reward, bool allownegative = false, bool print = true )
{
    // Nothing to update!
    if ( reward == 0 ) return;
    
    if ( !allownegative && reward < 0 ) return;
    
    
    int oldrank = GetRankClosest( g_nPoints[client] );
    int newrank = GetRankClosest( g_nPoints[client] + reward );
    
    g_nPoints[client] += reward;
    
    if ( g_ConVar_NotifyReward.BoolValue && print )
    {
        Influx_PrintToChat( _, client, "%T", "INF_GOTPOINTS", client, reward, g_nPoints[client] );
    }
    
    if ( oldrank != newrank && newrank != -1 )
    {
        // Update their rank.
        if ( !g_bChose[client] )
        {
            SetClientRank( client, newrank, false, _, g_ConVar_NotifyNewRank.BoolValue );
        }
    }
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
    
    
    SetMapReward( runid, reward );
    
    DB_UpdateMapReward( Influx_GetCurrentMapId(), runid, reward );
    
    char szRun[32];
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    
    Inf_ReplyToClient( issuer, "Set current map's {MAINCLR1}%s{CHATCLR} reward to {MAINCLR1}%i{CHATCLR} points.",
        szRun,
        reward );
}

stock bool CanUserUseCustomRank( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_CUSTOMRANK, ADMFLAG_ROOT );
}

stock bool CanUserSetMapReward( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_MAPREWARD, ADMFLAG_ROOT );
}

stock int SetMapReward( int runid, int points )
{
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Setting custom map rewards (runid: %i | points: %i)",
        runid,
        points );
#endif

    int index = FindMapRewardById( runid );
    if ( index != -1 )
    {
        g_hMapRewards.Set( index, points, Reward_t::nPoints );
        return index;
    }
    
    Reward_t reward;
    
    reward.iRunId = runid;
    reward.nPoints = points;
    
    
    return g_hMapRewards.PushArray( reward );
}

stock int FindMapRewardById( int runid )
{
    int len = g_hMapRewards.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hMapRewards.Get( i, Reward_t::iRunId ) == runid )
        {
            return i;
        }
    }
    
    return -1;
}

stock int GetMapRewardPointsSafe( int runid )
{
    int reward = GetMapRewardPoints( runid );
    
    // Must set custom amount for bonuses.
    if ( runid != MAIN_RUN_ID && reward < 0 ) return 0;
    
    
    return ( reward < 0 ) ? g_ConVar_DefMapReward.IntValue : reward;
}

stock int GetMapRewardPoints( int runid )
{
    int index = FindMapRewardById( runid );
    
    if ( index == -1 ) return -1;
    
    
    return g_hMapRewards.Get( index, Reward_t::nPoints );
}

stock int GetSecondReward( int reward )
{
    reward = RoundFloat( reward * g_ConVar_NotFirst.FloatValue );
    
    if ( g_ConVar_NotFirst.FloatValue != 0.0 && !reward )
    {
        reward = 1;
    }
    
    return reward;
}

stock int GetModePoints( int mode )
{
    decl String:sz[32];
    Influx_GetModeSafeName( mode, sz, sizeof( sz ) );
    int index = FindMultById( mode, sz, g_hModePoints );
    
    if ( index == -1 ) return 0;
    
    
    return g_hModePoints.Get( index, ModeNStyleReward_t::nPoints );
}

stock int GetStylePoints( int style )
{
    decl String:sz[32];
    Influx_GetStyleSafeName( style, sz, sizeof( sz ) );
    int index = FindMultById( style, sz, g_hStylePoints );
    
    if ( index == -1 ) return 0;
    
    
    return g_hStylePoints.Get( index, ModeNStyleReward_t::nPoints );
}

stock int FindMultById( int id, const char[] sz, ArrayList array )
{
    decl myid;
    decl String:szTemp[32];
    
    
    int len = array.Length;
    for ( int i = 0; i < len; i++ )
    {
        myid = array.Get( i, ModeNStyleReward_t::iId );
        
        if ( myid != -1 )
        {
            if ( myid == id ) return i;
        }
        else
        {
            array.GetString( i, szTemp, sizeof( szTemp ) );
            
            if ( StrEqual( sz, szTemp, false ) )
                return i;
        }
    }
    
    return -1;
}

stock int CalcReward( int runid, int mode, int style, bool bFirst )
{
    int reward = GetMapRewardPointsSafe( runid );
    
    if ( reward < 1 ) return 0;
    
    
    if ( !bFirst )
    {
        reward = GetSecondReward( reward );
    }
    
    int modepoints = GetModePoints( mode );
    int stylepoints = GetStylePoints( style );
    
    // Setting it to a negative value will disable rewards entirely.
    if ( modepoints < 0 )
        return 0;
    if ( stylepoints < 0 )
        return 0;
    
    return reward + modepoints + stylepoints;
}

// NOTE: Only increments cached value.
stock void GivePoints( const int[] targets, int nTargets, int points, int issuer = -1 )
{
    int valids = 0;
    
    for ( int i = 0; i < nTargets; i++ )
    {
        int target = targets[i];
        
        if ( target && IsClientInGame( target ) && !IsFakeClient( target ) && Influx_GetClientId( target ) > 0 )
        {
            IncClientPoints( target, points, true, false );
            
            DB_IncCachedPoints( target, points );
            
            if ( points > 0 )
            {
                Inf_ReplyToClient( target, "The universe gave you {MAINCLR1}%i{CHATCLR} points!", points, nTargets );
            }
            else
            {
                Inf_ReplyToClient( target, "The universe doesn't like you and took {MAINCLR1}%i{CHATCLR} points from you!", points, nTargets );
            }
            
            ++valids;
        }
    }
    
    if ( issuer >= 0 && (nTargets > 1 || targets[0] != issuer) )
    {
        Inf_ReplyToClient( issuer, "Gave {MAINCLR1}%i{CHATCLR} points to {MAINCLR1}%i{CHATCLR} player(s)!", points, valids );
    }
}

// Return true if a new clan tag was set.
stock bool UpdateClientClanTag( int client )
{
    if ( !g_ConVar_UseClanTag.BoolValue )
    {
        return false;
    }
    
    
    char szRankClanTag[256];
    char szClanTag[256];
    
    GetClientClanTagRank( client, szRankClanTag, sizeof( szRankClanTag ) );
    
    
    CS_GetClientClanTag( client, szClanTag, sizeof( szClanTag ) );
    
    
    if ( !StrEqual( szClanTag, szRankClanTag, true ) )
    {
        CS_SetClientClanTag( client, szRankClanTag );
        
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."Set %N's clan tag to '%s'. (old: %s)",
            client,
            szRankClanTag,
            szClanTag );
#endif
        return true;
    }
    else
    {
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."%N already has '%s' as a clan tag!",
            client,
            szClanTag );
#endif
        return false;
    }
}

stock void GetClientClanTagRank( int client, char[] out, int len )
{
    strcopy( out, len, g_szCurRank[client] );
    Influx_RemoveChatColors( out, len );
}

public Action T_CheckClanTags( Handle hTimer, any data )
{
    if ( !g_ConVar_UseClanTag.BoolValue )
    {
        return Plugin_Continue;
    }

    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame( i ) && !IsFakeClient( i ) )
        {
            UpdateClientClanTag( i );
        }
    }

    return Plugin_Continue;
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

public int Native_AddClientSimpleRankPoints( Handle hPlugin, int nParms )
{
    int iClient = GetNativeCell(1);
    int iPoints = GetNativeCell(2);

    if( !iClient || iPoints < 0 )
    {
        return 0;
    }

    DB_IncCachedPoints( iClient, iPoints );
    g_nPoints[iClient] += iPoints;

    return 1;
}
