#include <sourcemod>

#include <influx/core>
#include <influx/zones>
#include <influx/zones_stage>

#undef REQUIRE_PLUGIN
#include <influx/zones_checkpoint>


enum
{
    STAGE_ID = 0,
    
    STAGE_RUN_ID,
    
    STAGE_NUM,
    
    STAGE_ENTREF,
    
    STAGE_SIZE
};


ArrayList g_hStages;

int g_iStage[INF_MAXPLAYERS];
//int g_cache_nStages[INF_MAXPLAYERS];


ConVar g_ConVar_ActAsCP;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Zones | Stage",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_ZONES_STAGE );
    
    
    // NATIVES
    CreateNative( "Influx_ShouldDisplayStages", Native_ShouldDisplayStages );
    
    
    CreateNative( "Influx_GetClientStage", Native_GetClientStage );
    CreateNative( "Influx_GetClientStageCount", Native_GetClientStageCount );
    
    CreateNative( "Influx_GetRunStageCount", Native_GetRunStageCount );
}

public void OnPluginStart()
{
    g_hStages = new ArrayList( STAGE_SIZE );
    
    
    // CONVARS
    g_ConVar_ActAsCP = CreateConVar( "influx_stage_actascp", "1", "Stage zones act as checkpoints if checkpoints module is loaded.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
}

public void OnClientPutInServer( int client )
{
    g_iStage[client] = 1;
    //g_cache_nStages[client] = 0;
}

public void Influx_OnPreZoneLoad()
{
    g_hStages.Clear();
}

public Action Influx_OnZoneLoad( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_STAGE ) return Plugin_Continue;
    
    
    int runid = kv.GetNum( "run_id", -1 );
    if ( runid < 1 ) return Plugin_Stop;
    
    
    int stagenum = kv.GetNum( "stage_num", -1 );
    if ( stagenum < 1 ) return Plugin_Stop;
    
    
    decl data[STAGE_SIZE];
    
    data[STAGE_ID] = zoneid;
    
    data[STAGE_RUN_ID] = runid;
    
    data[STAGE_NUM] = stagenum;
    
    data[STAGE_ENTREF] = INVALID_ENT_REFERENCE;
    
    g_hStages.PushArray( data );
    
    
    
    if ( g_ConVar_ActAsCP.BoolValue )
    {
        char szName[MAX_CP_NAME];
        
        FormatEx( szName, sizeof( szName ), "Stage %i", stagenum );
        
        Influx_AddCP( runid, stagenum, szName );
    }
    
    
    return Plugin_Handled;
}

public Action Influx_OnZoneSave( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_STAGE ) return Plugin_Continue;
    
    
    int index = FindStageById( zoneid );
    if ( index == -1 ) return Plugin_Stop;
    
    
    kv.SetNum( "run_id", g_hStages.Get( index, STAGE_RUN_ID ) );
    
    kv.SetNum( "stage_num", g_hStages.Get( index, STAGE_NUM ) );
    
    return Plugin_Handled;
}

public void Influx_OnZoneCreated( int client, int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_CP ) return;
    
    
    int runid = Influx_GetClientRunId( client );
    if ( runid < 1 ) return;
    
    
    int stagenum = 1;//g_iBuildingNum[client];
    if ( stagenum < 1 ) return;
    
    
    
    decl data[STAGE_SIZE];
    
    data[STAGE_ID] = zoneid;
    
    data[STAGE_RUN_ID] = runid;
    
    data[STAGE_NUM] = stagenum;
    
    data[STAGE_ENTREF] = INVALID_ENT_REFERENCE;
    
    g_hStages.PushArray( data );
}

public void Influx_OnZoneSpawned( int zoneid, ZoneType_t zonetype, int ent )
{
    if ( zonetype != ZONETYPE_CP ) return;
    
    
    int index = FindStageById( zoneid );
    if ( index == -1 ) return;
    
    
    // Update ent reference.
    g_hStages.Set( index, EntIndexToEntRef( ent ), STAGE_ENTREF );
    
    
    SDKHook( ent, SDKHook_StartTouchPost, E_StartTouchPost_Stage );
    
    
    Inf_SetZoneProp( ent, g_hStages.Get( index, STAGE_ID ) );
}

public void E_StartTouchPost_Stage( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
    int index = FindStageById( Inf_GetZoneProp( ent ) );
    if ( index == -1 ) return;
    
    
    g_iStage[activator] = g_hStages.Get( index, STAGE_NUM );
    
    
    if ( g_ConVar_ActAsCP.BoolValue )
    {
        Influx_SaveClientCP( client, g_iStage[activator] );
    }
}

stock int FindStageById( int id )
{
    int len = g_hStages.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hStages.Get( i, STAGE_ID ) == id )
        {
            return i;
        }
    }
    
    return -1;
}

stock int GetRunStageCount( int runid )
{
    int num = 0;
    
    int len = g_hStages.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hStages.Get( i, STAGE_RUN_ID ) == runid )
        {
            ++num;
        }
    }
    
    return num;
}

// NATIVES
public int Native_ShouldDisplayStages( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    int runid = Influx_GetClientRunId( client );
    if ( runid != MAIN_RUN_ID ) return 0;
    
    
    return GetRunStageCount( runid ) > 0;
}

public int Native_GetClientStage( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return g_iStage[client];
}

public int Native_GetClientStageCount( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return GetRunStageCount( Influx_GetClientRunId( client ) );
}

public int Native_GetRunStageCount( Handle hPlugin, int nParms )
{
    int runid = GetNativeCell( 1 );
    
    return GetRunStageCount( runid );
}