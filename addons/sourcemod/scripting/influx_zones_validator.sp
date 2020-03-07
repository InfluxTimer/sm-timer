#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/zones>

#include <msharedutil/arrayvec>


enum // Zone - validators
{
    VAL_ID = 0,
    
    VAL_RUN_ID,
    
    VAL_SIZE
};

enum // Client validators.
{
    CVAL_ID = 0,
    
    CVAL_SIZE
};



ArrayList g_hValidatorsTouched[INF_MAXPLAYERS];

ArrayList g_hValidators;

// CONVARS
ConVar g_ConVar_MsgWhenTouched;
ConVar g_ConVar_ForceOrder;


bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Zones | Validator",
    description = "Players are required to enter all validator zones to finish the run.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    g_bLate = late;
    
    
    // LIBRARIES
    //RegPluginLibrary( INFLUX_LIB_ZONES_VALIDATOR );
}

public void OnPluginStart()
{
    g_hValidators = new ArrayList( VAL_SIZE );
    
    
    // CONVARS
    g_ConVar_MsgWhenTouched = CreateConVar( "influx_validator_msg", "1", "Do we tell the player that they have entered a validator zone?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_ForceOrder = CreateConVar( "influx_validator_forceorder", "0", "Does the player have to go through the validators in order?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );

    AutoExecConfig( true, "zones_validator", "influx" );
    
    
    if ( g_bLate )
    {
        Influx_OnPreRunLoad();
    }
}

public void OnAllPluginsLoaded()
{
    AddZoneType();
}

public void Influx_OnRequestZoneTypes()
{
    AddZoneType();
}

stock void AddZoneType()
{
    if ( !Influx_RegZoneType( ZONETYPE_VALIDATOR, "Validator", "validator", false ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't register zone type!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveZoneType( ZONETYPE_VALIDATOR );
}

public void OnClientPutInServer( int client )
{
    delete g_hValidatorsTouched[client];
    g_hValidatorsTouched[client] = new ArrayList( CVAL_SIZE );
}

public void Influx_OnPreRunLoad()
{
    g_hValidators.Clear();
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    OnClientPutInServer( client );
}

public Action Influx_OnTimerFinish( int client, int runid, int mode, int style, float time, int flags, char[] errormsg, int error_len )
{
    int nNeeded = GetNumValidators( runid );
    
    if ( nNeeded && AppliesToClient( client ) )
    {
        ArrayList touched = g_hValidatorsTouched[client];
        if ( !touched || touched.Length < nNeeded )
        {
            strcopy( errormsg, error_len, "You didn't enter all the validator zones!" );
            
            return Plugin_Stop;
        }
    }
    
    return Plugin_Continue;
}

public Action Influx_OnZoneLoad( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_VALIDATOR ) return Plugin_Continue;
    
    
    int runid = kv.GetNum( "run_id", -1 );
    if ( runid < 1 )
    {
        LogError( INF_CON_PRE..."Validator zone (id: %i) has invalid run id %i, loading anyway...",
            zoneid,
            runid );
    }
    
    AddValidator( runid, zoneid );
    
    return Plugin_Handled;
}

public Action Influx_OnZoneSave( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_VALIDATOR ) return Plugin_Continue;
    
    
    int index = FindValidatorById( zoneid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Validator zone (id: %i) is not registered with the plugin! Cannot save!",
            zoneid );
        return Plugin_Stop;
    }
    
    kv.SetNum( "run_id", g_hValidators.Get( index, VAL_RUN_ID ) );
    
    return Plugin_Handled;
}

public void Influx_OnZoneCreated( int client, int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_VALIDATOR ) return;
    
    
    int runid = Influx_GetClientRunId( client );
    
    AddValidator( runid, zoneid );
}

public void Influx_OnZoneDeleted( int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_VALIDATOR ) return;
    

    int index = FindValidatorById( zoneid );
    if ( index == -1 ) return;
    
    
    g_hValidators.Erase( index );
}

public void Influx_OnZoneSpawned( int zoneid, ZoneType_t zonetype, int ent )
{
    if ( zonetype != ZONETYPE_VALIDATOR ) return;

    
    SDKHook( ent, SDKHook_StartTouchPost, E_StartTouchPost_Validator );
    
    Inf_SetZoneProp( ent, zoneid );
}

public void E_StartTouchPost_Validator( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
    int zoneid = Inf_GetZoneProp( ent );
    
    int ival = FindValidatorById( zoneid );
    
    if ( ival == -1 )
    {
        return;
    }
    
    
    int myrunid = g_hValidators.Get( ival, VAL_RUN_ID );
    int runid = Influx_GetClientRunId( activator );
    
    if ( myrunid != runid )
        return;
    
    
    // We've already been here?
    if ( FindClientValidatorById( activator, zoneid ) != -1 )
        return;
    
    
    if ( g_ConVar_ForceOrder.BoolValue )
    {
        // We want to force the order of validator zones.
        // Is this not the supposed next validator zone?
        if ( FindClientNextValidatorIndex( activator ) != ival )
            return;
    }
    
    
    
    AddValidatorTouchedByIndex( activator, ival );
}

stock int AddValidator( int runid, int zoneid )
{
    int index = FindValidatorById( zoneid );
    if ( index != -1 ) return index;
    
    
    decl data[VAL_SIZE];
    
    data[VAL_ID] = zoneid;
    data[VAL_RUN_ID] = runid;
    
    return g_hValidators.PushArray( data );
}

stock int FindValidatorById( int id )
{
    int len = g_hValidators.Length;
    if ( len > 0 )
    {
        for ( int i = 0; i < len; i++ )
        {
            if ( g_hValidators.Get( i, VAL_ID ) == id ) return i;
        }
    }
    
    return -1;
}

stock int GetNumValidators( int runid )
{
    int num = 0;
    
    int len = g_hValidators.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hValidators.Get( i, VAL_RUN_ID ) == runid )
            ++num;
    }
    
    return num;
}

stock int FindClientValidatorById( int client, int id )
{
    ArrayList validator = g_hValidatorsTouched[client];
    
    int len = GetArrayLength_Safe( validator );
    if ( len > 0 )
    {
        for ( int i = 0; i < len; i++ )
        {
            if ( validator.Get( i, CVAL_ID ) == id ) return i;
        }
    }
    
    return -1;
}

stock int FindClientNextValidator( int client )
{
    int ival = FindClientNextValidatorIndex( client );
    if ( ival == -1 )
        return -1;
    
    
    return g_hValidators.Get( ival, VAL_ID );
}

stock int FindClientNextValidatorIndex( int client )
{
    int len;
    
    int runid = Influx_GetClientRunId( client );
    ArrayList validator = g_hValidatorsTouched[client];
    len = GetArrayLength_Safe( validator );
    
    // Get the last id we touched
    int lastzoneid = -1;
    if ( len > 0 )
    {
        lastzoneid = validator.Get( len -1, CVAL_ID );
    }
    
    // Just find the next highest zone id.
    int zoneid = -1;
    int index = -1;
    len = g_hValidators.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hValidators.Get( i, VAL_RUN_ID ) != runid )
            continue;
        
        
        int myzoneid = g_hValidators.Get( i, VAL_ID );
        
        if ( myzoneid > lastzoneid && (zoneid == -1 || myzoneid < zoneid) )
        {
            zoneid = myzoneid;
            index = i;
        }
    }
    
    return index;
}

stock void AddValidatorTouchedByIndex( int client, int ival )
{
    ArrayList touched = g_hValidatorsTouched[client];
    if ( touched == null ) return;
    
    
    decl data[CVAL_SIZE];
    data[CVAL_ID] = g_hValidators.Get( ival, VAL_ID );
    
    touched.PushArray( data );
    
    if ( g_ConVar_MsgWhenTouched.BoolValue )
    {
        Influx_PrintToChat( _, client, "You've entered a validator! ({MAINCLR1}%i{CHATCLR}/{MAINCLR1}%i{CHATCLR})",
            touched.Length,
            GetNumValidators( Influx_GetClientRunId( client ) ) );
    }
}

stock bool AppliesToClient( int client )
{
    // No TAS for now. No way to check if it's a valid run (reloaded run, rewind, etc.).
    return Influx_GetClientStyle( client ) != STYLE_TAS;
}
