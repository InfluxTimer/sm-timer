#include <sourcemod>

#include <influx/core>
#include <influx/zones_checkpoint>


#define CONFIG_NAME         "influx-sqlite2mysql"



#define QUERY_CREATETABLE_USERS_MYSQL   "CREATE TABLE IF NOT EXISTS "...INF_TABLE_USERS..." (\
                                        uid INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,\
                                        steamid VARCHAR(63) NOT NULL UNIQUE,\
                                        name VARCHAR(62) DEFAULT 'N/A',\
                                        joindate DATE NOT NULL)"


Handle g_hMySQL;
Handle g_hDB;


public void OnPluginStart()
{
    g_hDB = Influx_GetDB();
    
    if ( g_hDB == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve "...INF_NAME..." database!" );
    
    
    char szError[128];
    
    if ( SQL_CheckConfig( CONFIG_NAME ) )
    {
        g_hMySQL = SQL_Connect( CONFIG_NAME, true, szError, sizeof( szError ) );
    }
    else
    {
        SetFailState( INF_CON_PRE..."Couldn't find database config '%s'!", CONFIG_NAME );
    }
    
    if ( g_hMySQL == null )
    {
        SetFailState( INF_CON_PRE..."Unable to establish connection to MySQL database! (Error: %s)", szError );
    }
    
    
    PrintToServer( INF_CON_PRE..."Established connection to MySQL database!" );
    
    
    RegConsoleCmd( "sm_2mysql_tables", Cmd_CreateTables );
    RegConsoleCmd( "sm_2mysql_maps", Cmd_InsertMaps );
    RegConsoleCmd( "sm_2mysql_users", Cmd_InsertUsers );
    RegConsoleCmd( "sm_2mysql_times", Cmd_InsertTimes );
    RegConsoleCmd( "sm_2mysql_cptimes", Cmd_InsertCPTimes );
}

public Action Cmd_CreateTables( int client, int args )
{
    if ( client ) return Plugin_Handled;
    
    
    SQL_TQuery( g_hMySQL, Thrd_Empty, QUERY_CREATETABLE_USERS_MYSQL, _, DBPrio_High );
    
    SQL_TQuery( g_hMySQL, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_MAPS..." (" ...
        "mapid INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY," ...
        "mapname VARCHAR(127) NOT NULL UNIQUE)", _, DBPrio_High );
    
    SQL_TQuery( g_hMySQL, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_TIMES..." (" ...
        "uid INT NOT NULL," ...
        "mapid INT NOT NULL," ...
        "runid INT NOT NULL," ...
        "mode INT NOT NULL," ...
        "style INT NOT NULL," ...
        "rectime REAL NOT NULL," ...
        "recdate DATE NOT NULL," ...
        "jump_num INT DEFAULT -1," ...
        "strf_num INT DEFAULT -1," ...
        "PRIMARY KEY(uid,mapid,runid,mode,style))", _, DBPrio_High );
    
    SQL_TQuery( g_hMySQL, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_CPTIMES..." (" ...
        "uid INT NOT NULL," ...
        "mapid INT NOT NULL," ...
        "runid INT NOT NULL," ...
        "mode INT NOT NULL," ...
        "style INT NOT NULL," ...
        "cpnum INT NOT NULL," ...
        "cptime REAL NOT NULL," ...
        "PRIMARY KEY(uid,mapid,runid,mode,style,cpnum))", _, DBPrio_High );
    
    
    PrintToServer( INF_CON_PRE..."Queries sent." );
        
    return Plugin_Handled;
}

public Action Cmd_InsertMaps( int client, int args )
{
    if ( client ) return Plugin_Handled;
    
    
    int field;
    char szQuery[1024];
    
    int mapid;
    char mapname[128];
    
    
    Handle res = DB_Query( "SELECT mapid,mapname FROM "...INF_TABLE_MAPS );
    if ( res == null ) return Plugin_Handled;
    
    while ( SQL_FetchRow( res ) )
    {
        SQL_FieldNameToNum( res, "mapid", field );
        mapid = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "mapname", field );
        SQL_FetchString( res, field, mapname, sizeof( mapname ) );
        
        FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...INF_TABLE_MAPS..." (mapid,mapname) VALUES (%i,'%s')", mapid, mapname );
        
        SQL_TQuery( g_hMySQL, Thrd_Maps, szQuery, _, DBPrio_Normal );
        
        /*if ( !SQL_FastQuery( g_hMySQL, szQuery ) )
        {
            Inf_DB_LogError( g_hMySQL, "inserting maps to MySQL!" );
        }*/
    }
    
    delete res;
    
    
    PrintToServer( INF_CON_PRE..."Queries sent." );
    
    return Plugin_Handled;
}

public Action Cmd_InsertUsers( int client, int args )
{
    if ( client ) return Plugin_Handled;
    
    
    int field;
    char szQuery[1024];
    
    int uid;
    char steamid[128];
    char name[128];
    char joindate[64];
    
    Handle res = DB_Query( "SELECT * FROM "...INF_TABLE_USERS );
    if ( res == null ) return Plugin_Handled;
    
    while ( SQL_FetchRow( res ) )
    {
        SQL_FieldNameToNum( res, "uid", field );
        uid = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "steamid", field );
        SQL_FetchString( res, field, steamid, sizeof( steamid ) );
        
        SQL_FieldNameToNum( res, "name", field );
        SQL_FetchString( res, field, name, sizeof( name ) );
        
        SQL_FieldNameToNum( res, "joindate", field );
        SQL_FetchString( res, field, joindate, sizeof( joindate ) );
        
        if ( !SQL_EscapeString( g_hMySQL, name, name, sizeof( name ) ) )
        {
            strcopy( name, sizeof( name ), "Something went wrong!" );
        }
        
        FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...INF_TABLE_USERS..." (uid,steamid,name,joindate) VALUES (%i,'%s','%s','%s')", uid, steamid, name, joindate );
        
        SQL_TQuery( g_hMySQL, Thrd_Users, szQuery, _, DBPrio_Normal );
        
        /*if ( !SQL_FastQuery( g_hMySQL, szQuery ) )
        {
            Inf_DB_LogError( g_hMySQL, "inserting users to MySQL!" );
        }*/
    }
    
    delete res;
    
    
    PrintToServer( INF_CON_PRE..."Queries sent." );
    
    return Plugin_Handled;
}

public Action Cmd_InsertTimes( int client, int args )
{
    if ( client ) return Plugin_Handled;
    
    
    int field;
    char szQuery[1024];
    
    int uid;
    int mapid;
    int runid;
    int mode;
    int style;
    float rectime;
    char recdate[64];
    int jump_num;
    int strf_num;
    
    Handle res = DB_Query( "SELECT * FROM "...INF_TABLE_TIMES );
    if ( res == null ) return Plugin_Handled;
    
    while ( SQL_FetchRow( res ) )
    {
        SQL_FieldNameToNum( res, "uid", field );
        uid = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "mapid", field );
        mapid = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "runid", field );
        runid = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "mode", field );
        mode = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "style", field );
        style = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "rectime", field );
        rectime = SQL_FetchFloat( res, field );
        
        SQL_FieldNameToNum( res, "recdate", field );
        SQL_FetchString( res, field, recdate, sizeof( recdate ) );
        
        SQL_FieldNameToNum( res, "jump_num", field );
        jump_num = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "strf_num", field );
        strf_num = SQL_FetchInt( res, field );
        
        
        FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...INF_TABLE_TIMES..." (uid,mapid,runid,mode,style,rectime,recdate,jump_num,strf_num) VALUES (%i,%i,%i,%i,%i,%f,'%s',%i,%i)",
            uid,
            mapid,
            runid,
            mode,
            style,
            rectime,
            recdate,
            jump_num,
            strf_num );
        
        SQL_TQuery( g_hMySQL, Thrd_Times, szQuery, _, DBPrio_Normal );
        
        /*if ( !SQL_FastQuery( g_hMySQL, szQuery ) )
        {
            Inf_DB_LogError( g_hMySQL, "inserting times to MySQL!" );
        }*/
    }
    
    delete res;
    
    
    PrintToServer( INF_CON_PRE..."Queries sent." );
    
    return Plugin_Handled;
}

public Action Cmd_InsertCPTimes( int client, int args )
{
    if ( client ) return Plugin_Handled;
    
    
    int field;
    char szQuery[1024];
    
    
    int uid;
    int mapid;
    int runid;
    int mode;
    int style;
    
    int cpnum;
    float cptime;
    
    
    Handle res = DB_Query( "SELECT * FROM "...INF_TABLE_CPTIMES );
    if ( res == null ) return Plugin_Handled;
    
    while ( SQL_FetchRow( res ) )
    {
        SQL_FieldNameToNum( res, "uid", field );
        uid = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "mapid", field );
        mapid = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "runid", field );
        runid = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "mode", field );
        mode = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "style", field );
        style = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "cpnum", field );
        cpnum = SQL_FetchInt( res, field );
        
        SQL_FieldNameToNum( res, "cptime", field );
        cptime = SQL_FetchFloat( res, field );
        
        
        FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...INF_TABLE_CPTIMES..." (uid,mapid,runid,mode,style,cpnum,cptime) VALUES (%i,%i,%i,%i,%i,%i,%f)",
            uid,
            mapid,
            runid,
            mode,
            style,
            cpnum,
            cptime );
        
        SQL_TQuery( g_hMySQL, Thrd_CPTimes, szQuery, _, DBPrio_Normal );
        
        /*if ( !SQL_FastQuery( g_hMySQL, szQuery ) )
        {
            Inf_DB_LogError( g_hMySQL, "inserting checkpoint times to MySQL!" );
        }*/
    }
    
    delete res;
    
    
    PrintToServer( INF_CON_PRE..."Queries sent." );
    
    return Plugin_Handled;
}

stock Handle DB_Query( const char[] szQuery )
{
    Handle res = SQL_Query( g_hDB, szQuery );
    
    if ( res == null )
    {
        char szError[256];
        SQL_GetError( g_hDB, szError, sizeof( szError ) );
        
        LogError( INF_CON_PRE..."Error: %s", szError );
        
        return null;
    }
    
    return res;
}

public void Thrd_Empty( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hMySQL, "creating tables to MySQL!" );
    }
}

public void Thrd_Maps( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hMySQL, "inserting maps to MySQL!" );
    }
}

public void Thrd_Users( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hMySQL, "inserting users to MySQL!" );
    }
}

public void Thrd_Times( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hMySQL, "inserting times to MySQL!" );
    }
}

public void Thrd_CPTimes( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hMySQL, "inserting checkpoint times to MySQL!" );
    }
}