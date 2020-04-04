#include <sourcemod>

#include <influx/core>

#include <msharedutil/ents>


//#define DEBUG


#define T_SPAWN             "info_player_terrorist"
#define CT_SPAWN            "info_player_counterterrorist"


#define TF_SPAWN            "info_player_teamspawn"
#define GAME_SPAWN          "info_player_start"
#define ABSLAST_SPAWN       "info_player_logo"


ConVar g_ConVar_Num;
ConVar g_ConVar_RemoveOthers;
ConVar g_ConVar_Prefer;
ConVar g_ConVar_CreateInMain;



//bool g_bIsCS;
bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Spawn points",
    description = "Creates spawn points if the map doesn't have enough of them.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    g_bLate = late;
}

public void OnPluginStart()
{
    g_ConVar_Num = CreateConVar( "influx_spawnpoints_num", "32", "How many spawn points we need.", FCVAR_NOTIFY );
    g_ConVar_RemoveOthers = CreateConVar( "influx_spawnpoints_removeothers", "0", "If true, all other spawn point entities are removed. Don't use outside skill surf/bhop.", FCVAR_NOTIFY );
    g_ConVar_Prefer = CreateConVar( "influx_spawnpoints_prefer", "0", "Which spawn point to prefer first. 0 = CT, 1 = T, 2 = Balance both", FCVAR_NOTIFY );
    g_ConVar_CreateInMain = CreateConVar( "influx_spawnpoints_createinmain", "0", "", FCVAR_NOTIFY );
    
    AutoExecConfig( true, "spawnpoints", "influx" );
    
    
    //EngineVersion ver = GetEngineVersion();
    //g_bIsCS = ver == Engine_CSS || ver == Engine_CSGO;
    
    if ( g_bLate )
    {
        CheckSpawns( false );
    }
}

public void OnMapStart()
{
    CheckSpawns( true );
}

stock void CheckSpawns( bool bOnMapStart )
{
    if ( g_ConVar_Num.IntValue <= 0 )
        return;
    
    
    // Want to create at main run?
    // Only allow one-sided.
    if ( !bOnMapStart && g_ConVar_Prefer.IntValue != 2 && g_ConVar_CreateInMain.BoolValue )
    {
        if ( CreateSpawnsAtMain() )
            return;
    }
    
    if ( g_ConVar_Prefer.IntValue == 2 )
    {
        CreateBalanced();
    }
    else
    {
        CreateOneSided();
    }
}

// Both teams get equal amount of spawns.
stock void CreateBalanced()
{
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Creating balanced spawns..." );
#endif
    
    int copy_ent_ct = FindValidSpawn( CT_SPAWN );
    int copy_ent_t = FindValidSpawn( T_SPAWN );
    int num_ct = GetEntityCountByClassname( CT_SPAWN, true );
    int num_t = GetEntityCountByClassname( T_SPAWN, true );
    
    
    if ( !num_ct || !num_t || copy_ent_ct == -1 || copy_ent_t == -1 )
    {
        LogError( INF_CON_PRE..."Can't create balanced spawns if one side doesn't have any valid spawns! (CT: %i, T: %i)", num_ct, num_t );
        
        CreateOneSided();
        return;
    }
    
    
    float pos_ct[3], ang_ct[3];
    float pos_t[3], ang_t[3];
    GetSpawnData( copy_ent_ct, pos_ct, ang_ct );
    GetSpawnData( copy_ent_t, pos_t, ang_t );
    
    // Remove others before starting to create
    if ( g_ConVar_RemoveOthers.BoolValue )
    {
        RemoveSpawns();
    }
    
    
    int nWanted = g_ConVar_Num.IntValue / 2;
    
    CreateSpawns( nWanted - num_ct, CT_SPAWN, pos_ct, ang_ct );
    CreateSpawns( nWanted - num_t, T_SPAWN, pos_t, ang_t );
}

stock bool CreateSpawnsAtMain()
{
    int irun = Influx_FindRunById( MAIN_RUN_ID );
    if ( irun == -1 )
        return false;
    
    
    ArrayList runs = Influx_GetRunsArray();
    
    float pos[3];
    float yaw;
    
    for ( int i = 0; i < 3; i++ )
        pos[i] = runs.Get( irun, RUN_TELEPOS + i );
    yaw = runs.Get( irun, RUN_TELEYAW );
    
    
    if ( !Inf_IsValidTelePos( pos ) || !Inf_IsValidTeleAngle( yaw ) )
        return false;
    
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Creating spawns in main..." );
#endif
    
    CreateSpawnsAtPos( pos, yaw );
    return true;
}

stock void CreateSpawnsAtPos( const float pos[3], float yaw )
{
    char szSpawn[64];
    GetPreferredSpawnClass( szSpawn, sizeof( szSpawn ) );
    
    
    
    // Remove others before starting to create
    if ( g_ConVar_RemoveOthers.BoolValue )
    {
        RemoveSpawns();
    }
    
    
    float ang[3];
    ang[1] = yaw;
    
    
    int nWanted = g_ConVar_Num.IntValue;
    
    int num = GetEntityCountByClassname( szSpawn );
    
    
    CreateSpawns( nWanted - num, szSpawn, pos, ang );
}

// We only care about the number of spawns. ie. for skill surf/bhop servers
stock void CreateOneSided()
{
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Creating one-sided spawns..." );
#endif

    int copy_ent = -1;
    int ent = -1;
    
    
    char szSpawn[64];
    char szFallbackSpawn[64];
    GetPreferredSpawnClass( szSpawn, sizeof( szSpawn ) );
    GetFallbackSpawnClass( szFallbackSpawn, sizeof( szFallbackSpawn ) );
    
    
    if ( (ent = FindValidSpawn( szSpawn )) != -1 )
    {
        copy_ent = ent;
    }
    else if ( (ent = FindValidSpawn( szFallbackSpawn )) != -1 )
    {
        copy_ent = ent;
        
        // Preferred spawns doesn't work
        // Flip them
        char copy[64];
        strcopy( copy, sizeof( copy ), szFallbackSpawn );
        strcopy( szFallbackSpawn, sizeof( szFallbackSpawn ), szSpawn );
        strcopy( szSpawn, sizeof( szSpawn ), copy );
    }
    // We have no CSS spawns, look for others
    else if (   (ent = FindValidSpawn( TF_SPAWN )) != -1
    ||          (ent = FindValidSpawn( GAME_SPAWN )) != -1
    ||          (ent = FindValidSpawn( ABSLAST_SPAWN )) != -1)
    {
        copy_ent = ent;
    }
    
    
    if ( copy_ent == -1 )
    {
        LogError( INF_CON_PRE..."Map has no spawns whatsoever!" );
        return;
    }
    
    
    float pos[3];
    float ang[3];
    GetSpawnData( copy_ent, pos, ang );
    
    
    // Remove others before starting to create
    if ( g_ConVar_RemoveOthers.BoolValue )
    {
        RemoveSpawns();
    }
    
    
    
    int nWanted = g_ConVar_Num.IntValue;
    
    int num = GetEntityCountByClassname( szSpawn );
    
    
    CreateSpawns( nWanted - num, szSpawn, pos, ang );
}

stock int CreateSpawns( int num, const char[] szClass, const float pos[3], const float ang[3] )
{
    if ( num <= 0 )
        return 0;
    
    
    int ent;
    int nCreated = 0;
    
    for ( int i = 0; i < num; i++ )
    {
        ent = CreateEntityByName( szClass );
        
        if ( ent == -1 || !DispatchSpawn( ent ) )
        {
            LogError( INF_CON_PRE..."Couldn't spawn spawnpoint entity %s!", szClass );
            continue;
        }
        
        ActivateEntity( ent );
        TeleportEntity( ent, pos, ang, NULL_VECTOR );
        
        
        ++nCreated;
    }
    
    PrintToServer( INF_CON_PRE..."Created %i '%s' spawnpoints!", nCreated, szClass );
    
    
    return nCreated;
}

stock void GetSpawnData( int ent, float pos[3], float ang[3] )
{
    GetEntPropVector( ent, Prop_Data, "m_vecOrigin", pos );
    GetEntPropVector( ent, Prop_Data, "m_angRotation", ang );
    ang[2] = 0.0;
}

stock int RemoveSpawns()
{
    int total = 0;
    total += RemoveAllByClassname( CT_SPAWN );
    total += RemoveAllByClassname( T_SPAWN );
    total += RemoveAllByClassname( TF_SPAWN );
    total += RemoveAllByClassname( GAME_SPAWN );
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Removed %i spawns...", total );
#endif
    
    return total;
}

stock int GetEntityCountByClassname( const char[] szClass, bool bCheckValidSpawn = false )
{
    int num = 0;
    int ent = -1;
    while ( (ent = FindEntityByClassname( ent, szClass )) != -1 )
    {
        // Ignore dying entities.
        if ( GetEntityFlags( ent ) & FL_KILLME )
            continue;

        if ( bCheckValidSpawn && !IsSpawnWithinMap( ent ) )
            continue;
        
        ++num;
    }
    
    return num;
}

stock int RemoveAllByClassname( const char[] szClass )
{
    int num = 0;
    
    int ent = -1;
    while ( (ent = FindEntityByClassname( ent, szClass )) != -1 )
    {
        // Ignore dying entities.
        if ( GetEntityFlags( ent ) & FL_KILLME )
            continue;
        
        KillEntity( ent );

        // Make sure we detect this entity as dying.
        // For some reason KillEntity does not set this.
        SetEntityFlags( ent, GetEntityFlags( ent ) | FL_KILLME );
        
        ++num;
    }
    
    return num;
}

stock void GetPreferredSpawnClass( char[] szSpawn, int len )
{
    if ( g_ConVar_Prefer.IntValue != 1 )
    {
        // Use CT
        strcopy( szSpawn, len, CT_SPAWN );
    }
    else
    {
        // Use T
        strcopy( szSpawn, len, T_SPAWN );
    }
}

stock void GetFallbackSpawnClass( char[] szFallbackSpawn, int len )
{
    if ( g_ConVar_Prefer.IntValue != 1 )
    {
        // Use CT
        strcopy( szFallbackSpawn, len, T_SPAWN );
    }
    else
    {
        // Use T
        strcopy( szFallbackSpawn, len, CT_SPAWN );
    }
}

stock int FindValidSpawn( const char[] szSpawnClass )
{
    int ent = -1;
    while ( (ent = FindEntityByClassname( ent, szSpawnClass )) != -1 )
    {
        if ( IsSpawnWithinMap( ent ) )
        {
            return ent;
        }
    }

    return -1;
}

stock bool IsSpawnWithinMap( ent )
{
    float end[3];

    float pos[3];
    float ang[3];
    GetSpawnData( ent, pos, ang );


    end = pos;
    end[2] += 72.0;

    float mins[] = { -16.0, -16.0, 0.0 };
    float maxs[] = { 16.0, 16.0, 0.0 };

    // Mask that only hits solid world (ignore moveables ents at least for now.)
    int mask = ( CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE );

    TR_TraceHull( pos, end, mins, maxs, mask );

    bool bValid = !TR_DidHit();
    if ( !bValid )
    {
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."Detected spawnpoint %i that is outside the map!", ent );
#endif
        return false;
    }

    return true;
}
