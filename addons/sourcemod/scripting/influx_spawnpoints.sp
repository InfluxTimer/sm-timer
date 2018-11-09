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
    g_ConVar_RemoveOthers = CreateConVar( "influx_spawnpoints_removeothers", "1", "If true, all other spawn point entities are removed. Don't use outside skill surf/bhop.", FCVAR_NOTIFY );
    g_ConVar_Prefer = CreateConVar( "influx_spawnpoints_prefer", "0", "Which spawn point to prefer first. 0 = CT, 1 = T, 2 = Balance both", FCVAR_NOTIFY );
    g_ConVar_CreateInMain = CreateConVar( "influx_spawnpoints_createinmain", "1", "", FCVAR_NOTIFY );
    
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

    int ent;
    
    int copy_ent_ct = -1;
    int copy_ent_t = -1;
    int num_ct = 0;
    int num_t = 0;
    
    
    ent = -1;
    while ( (ent = FindEntityByClassname( ent, CT_SPAWN )) != -1 )
    {
        if ( copy_ent_ct == -1 )
            copy_ent_ct = ent;
        
        ++num_ct;
    }
    ent = -1;
    while ( (ent = FindEntityByClassname( ent, T_SPAWN )) != -1 )
    {
        if ( copy_ent_t == -1 )
            copy_ent_t = ent;
        
        ++num_t;
    }
    
    
    if ( !num_ct || !num_t )
    {
        LogError( INF_CON_PRE..."Can't create balanced spawns if one side doesn't have any spawns! (CT: %i, T: %i)", num_ct, num_t );
        
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
    
    
    if ( (ent = FindEntityByClassname( ent, szSpawn )) != -1 )
    {
        copy_ent = ent;
    }
    else if ( (ent = FindEntityByClassname( ent, szFallbackSpawn )) != -1 )
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
    else if (   (ent = FindEntityByClassname( ent, TF_SPAWN )) != -1
    ||          (ent = FindEntityByClassname( ent, GAME_SPAWN )) != -1
    ||          (ent = FindEntityByClassname( ent, ABSLAST_SPAWN )) != -1)
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

stock int GetEntityCountByClassname( const char[] szClass )
{
    int num = 0;
    int ent = -1;
    while ( (ent = FindEntityByClassname( ent, szClass )) != -1 )
    {
        // Ignore dying entities.
        if ( GetEntityFlags( ent ) & FL_KILLME )
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
