#include "influx_simpleranks/db_cb.sp"


stock void DB_Init()
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    SQL_TQuery( db, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_SIMPLERANKS..." (" ...
        "uid INT NOT NULL," ...
        "points INT NOT NULL," ...
        "chosenrank INT NOT NULL," ...
        "PRIMARY KEY(uid))", _, DBPrio_High );
        
    SQL_TQuery( db, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_SIMPLERANKS_MAPS..." (" ...
        "mapid INT NOT NULL," ...
        "rewardpoints INT NOT NULL," ...
        "PRIMARY KEY(mapid))", _, DBPrio_High );
}

stock void DB_InitMap( int mapid )
{
    Handle db = Influx_GetDB();
    
    static char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT rewardpoints FROM "...INF_TABLE_SIMPLERANKS_MAPS..." WHERE mapid=%i", mapid );
    
    
    SQL_TQuery( db, Thrd_InitMap, szQuery, _, DBPrio_Normal );
}

stock void DB_InitClient( int client )
{
    Handle db = Influx_GetDB();
    
    static char szQuery[256];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT points,chosenrank FROM "...INF_TABLE_SIMPLERANKS..." WHERE uid=%i", Influx_GetClientId( client ) );
    
    
    SQL_TQuery( db, Thrd_InitClient, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_CheckClientRecCount( int client, int runid, int mode, int style )
{
    Handle db = Influx_GetDB();
    
    // See if the player has already beaten this map.
    decl data[4];
    
    data[0] = GetClientUserId( client );
    data[1] = runid;
    data[2] = mode;
    data[3] = style;
    
    ArrayList array = new ArrayList( sizeof( data ) );
    array.PushArray( data );

    
    static char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT runid,mode,style FROM "...INF_TABLE_TIMES..." WHERE uid=%i AND mapid=%i", Influx_GetClientId( client ), Influx_GetCurrentMapId() );
    
    SQL_TQuery( db, Thrd_CheckClientRecCount, szQuery, array, DBPrio_Normal );
}

stock void DB_IncClientPoints( int client, int reward )
{
    Handle db = Influx_GetDB();
    
    static char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "UPDATE "...INF_TABLE_SIMPLERANKS..." SET points=points+%i WHERE uid=%i", reward, Influx_GetClientId( client ) );
    
    SQL_TQuery( db, Thrd_Empty, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_UpdateMapReward( int mapid, int reward, int issuer = 0 )
{
    Handle db = Influx_GetDB();
    
    char szQuery[256];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "REPLACE INTO "...INF_TABLE_SIMPLERANKS_MAPS..." (mapid,rewardpoints) VALUES (%i,%i)",
        mapid,
        reward );
    
    SQL_TQuery( db, Thrd_Empty, szQuery, issuer ? GetClientUserId( issuer ) : 0, DBPrio_Normal );
}

stock void DB_UpdateClientChosenRank( int client, const char[] szRank )
{
    Handle db = Influx_GetDB();
    
    decl String:szSafe[MAX_RANK_SIZE];
    strcopy( szSafe, sizeof( szSafe ), szRank );
    
    RemoveChars( szSafe, "`'\"" );
    
    
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "UPDATE "...INF_TABLE_SIMPLERANKS..." SET chosenrank='%s' WHERE uid=%i",
        szSafe,
        Influx_GetClientId( client ) );
    
    SQL_TQuery( db, Thrd_Empty, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_SetMapRewardByName( int client, int reward, const char[] szMap )
{
    Handle db = Influx_GetDB();
    
    decl data[2];
    data[0] = ( client ) ? GetClientUserId( client ) : 0;
    data[1] = reward;
    
    ArrayList array = new ArrayList( sizeof( data ) );
    array.PushArray( data );
    
    
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT mapid,mapname FROM "...INF_TABLE_MAPS..." WHERE mapname='%s'", szMap );
    
    SQL_TQuery( db, Thrd_SetMapReward, szQuery, array, DBPrio_Normal );
}