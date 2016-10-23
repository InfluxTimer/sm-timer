#include <sourcemod>

#include <influx/core>


public void OnPluginStart()
{
    // Usage: sm_updatename "WHATEVER NAME"
    RegAdminCmd( "sm_updatename", Cmd_UpdateName, ADMFLAG_ROOT );
}

public Action Cmd_UpdateName( int client, int args )
{
    if ( !args )
    {
        return Plugin_Handled;
    }
    
    // Retrieve the database handle we use.
    Handle db = Influx_GetDB();
    
    if ( db == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    }
    
    
    char name[256];
    GetCmdArgString( name, sizeof( name ) );
    
    StripQuotes( name );
    
    if ( !SQL_EscapeString( db, name, name, sizeof( name ) ) )
    {
        strcopy( name, sizeof( name ), "Something went wrong!" );
    }
    
    
    int uid = Influx_GetClientId( client );
    if ( uid < 1 ) uid = 1;
    
    
    // Core table names can be found in influx/core.inc
    char szQuery[512];
    FormatEx( szQuery, sizeof( szQuery ), "UPDATE "...INF_TABLE_USERS..." SET name='%s' WHERE uid=%i", name, uid );
    
    
    SQL_TQuery( db, Thrd_Empty, szQuery, _, DBPrio_High );
    
    return Plugin_Handled;
}

public void Thrd_Empty( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "testing database" );
    }
}