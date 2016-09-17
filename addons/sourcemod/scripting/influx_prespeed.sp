#include <sourcemod>

#include <influx/core>
#include <influx/stocks_core>

#undef REQUIRE_PLUGIN
#include <influx/runs_sql>


//#define DEBUG


enum
{
    PRESPEED_RUN_ID = 0,
    
    PRESPEED_MAX,
    
    PRESPEED_CAP,
    PRESPEED_USETRUEVEL,
    
    PRESPEED_SIZE
};

ArrayList g_hPre;


// CONVARS
ConVar g_ConVar_Max;
ConVar g_ConVar_UseTrueVel;
ConVar g_ConVar_Cap;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Prespeed",
    description = "Handles prespeed.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    g_hPre = new ArrayList( PRESPEED_SIZE );
    
    
    // CONVARS
    g_ConVar_Max = CreateConVar( "influx_prespeed_max", "300", "Default max prespeed. 0 = disable", FCVAR_NOTIFY, true, 0.0 );
    g_ConVar_UseTrueVel = CreateConVar( "influx_prespeed_usetruevel", "0", "Use truevel when checking player's speed.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_Cap = CreateConVar( "influx_prespeed_cap", "1", "If true, cap player's speed to max prespeed. Otherwise teleport.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    AutoExecConfig( true, "prespeed", "influx" );
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
    
    data[PRESPEED_MAX] = view_as<int>( g_ConVar_Max.FloatValue );
    data[PRESPEED_USETRUEVEL] = g_ConVar_UseTrueVel.BoolValue;
    data[PRESPEED_CAP] = g_ConVar_Cap.BoolValue;
    
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

public void Influx_OnRunLoad_SQL( int runid, Handle res )
{
    int index = FindPreById( runid );
    if ( index == -1 ) return;
    
    
    
    int field;
    
    
    decl data[PRESPEED_SIZE];
    g_hPre.GetArray( index, data );
    
    
    data[PRESPEED_RUN_ID] = runid;
    
    SQL_FieldNameToNum( res, "prespeed_max", field );
    data[PRESPEED_MAX] = view_as<int>( SQL_FetchFloat( res, field ) );
    
    SQL_FieldNameToNum( res, "prespeed_usetruevel", field );
    data[PRESPEED_USETRUEVEL] = SQL_FetchInt( res, field ) ? 1 : 0;
    
    SQL_FieldNameToNum( res, "prespeed_cap", field );
    data[PRESPEED_CAP] = SQL_FetchInt( res, field ) ? 1 : 0;
    
    g_hPre.PushArray( data );
}

public void Influx_OnRunLoad( int runid, KeyValues kv )
{
    if ( FindPreById( runid ) != -1 ) return;
    
    
    decl data[PRESPEED_SIZE];
    
    data[PRESPEED_RUN_ID] = runid;
    
    data[PRESPEED_MAX] = view_as<int>( kv.GetFloat( "prespeed_max", g_ConVar_Max.FloatValue ) );
    data[PRESPEED_USETRUEVEL] = kv.GetNum( "prespeed_usetruevel", g_ConVar_UseTrueVel.IntValue ) ? 1 : 0;
    data[PRESPEED_CAP] = kv.GetNum( "prespeed_cap", g_ConVar_Cap.IntValue ) ? 1 : 0;
    
    g_hPre.PushArray( data );
}

public void Influx_OnRunSave( int runid, KeyValues kv )
{
    int index = FindPreById( runid );
    if ( index == -1 ) return;
    
    
    decl data[PRESPEED_SIZE];
    g_hPre.GetArray( index, data );
    
    float maxprespd = view_as<float>( data[PRESPEED_MAX] );
    bool truevel = data[PRESPEED_USETRUEVEL] ? true : false;
    bool cap = data[PRESPEED_CAP] ? true : false;
    
    if ( maxprespd != g_ConVar_Max.FloatValue )
    {
        kv.SetFloat( "prespeed_max", maxprespd );
    }
    
    if ( truevel != g_ConVar_UseTrueVel.BoolValue )
    {
        kv.SetNum( "prespeed_usetruevel", truevel );
    }
    
    if ( cap != g_ConVar_Cap.BoolValue )
    {
        kv.SetNum( "prespeed", cap );
    }
}

public Action Influx_OnTimerStart( int client, int runid, char[] errormsg, int error_len )
{
    int index = FindPreById( runid );
    if ( index == -1 ) return Plugin_Continue;
    
    
    // Check prespeed.
    float maxprespd = g_hPre.Get( index, PRESPEED_MAX );
    
    if ( maxprespd > 0.0 )
    {
        float vel[3];
        GetEntityVelocity( client, vel );
        
        bool bBadSpd = false;
        
        float spd = SquareRoot( vel[0] * vel[0] + vel[1] * vel[1] );
        float truespd = SquareRoot( vel[0] * vel[0] + vel[1] * vel[1] + vel[2] * vel[2] );
        
        if ( g_hPre.Get( index, PRESPEED_USETRUEVEL ) )
        {
            bBadSpd = ( truespd > maxprespd );
        }
        else
        {
            bBadSpd = ( spd > maxprespd );
        }
        
        if ( bBadSpd )
        {
#if defined DEBUG
            PrintToServer( INF_DEBUG_PRE..."Bad prespeed (%i) (%.1f | %.1f)", client, spd, truespd );
#endif
            if ( g_hPre.Get( index, PRESPEED_CAP ) )
            {
                float m = truespd / maxprespd;
                
                vel[0] /= m;
                vel[1] /= m;
                vel[2] /= m;
                
                TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, vel );
            }
            else
            {
                FormatEx( errormsg, error_len, "Your prespeed cannot exceed %.0f!", maxprespd );
                return Plugin_Handled;
            }
        }
    }
    
    return Plugin_Continue;
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