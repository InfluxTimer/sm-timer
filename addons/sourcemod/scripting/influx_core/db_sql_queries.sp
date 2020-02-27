
//
// Create inf_users table
//
#define QUERY_CREATETABLE_USERS_MYSQL   "\
    CREATE TABLE IF NOT EXISTS "...INF_TABLE_USERS..." (\
        uid INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,\
        steamid VARCHAR(63) NOT NULL UNIQUE,\
        name VARCHAR(62) DEFAULT 'N/A',\
        joindate DATE NOT NULL)\
    "

// NOTE: Must be INTEGER PRIMARY KEY.
// https://www.sqlite.org/autoinc.html
#define QUERY_CREATETABLE_USERS_SQLITE "\
    CREATE TABLE IF NOT EXISTS "...INF_TABLE_USERS..." (\
        uid INTEGER PRIMARY KEY,\
        steamid VARCHAR(63) NOT NULL UNIQUE,\
        name VARCHAR(62) DEFAULT 'N/A',\
        joindate DATE NOT NULL)\
    "

//
// Create inf_maps table
//
#define QUERY_CREATETABLE_MAPS_MYSQL "\
    CREATE TABLE IF NOT EXISTS "...INF_TABLE_MAPS..." (\
        mapid INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,\
        mapname VARCHAR(127) NOT NULL UNIQUE)\
    "


#define QUERY_CREATETABLE_MAPS_SQLITE "\
    CREATE TABLE IF NOT EXISTS "...INF_TABLE_MAPS..." (\
        mapid INTEGER PRIMARY KEY,\
        mapname VARCHAR(127) NOT NULL UNIQUE)\
    "


//
// Create inf_times table
//
#define QUERY_CREATETABLE_TIMES "\
    CREATE TABLE IF NOT EXISTS "...INF_TABLE_TIMES..." (\
        uid INT NOT NULL,\
        mapid INT NOT NULL,\
        runid INT NOT NULL,\
        mode INT NOT NULL,\
        style INT NOT NULL,\
        rectime REAL NOT NULL,\
        recdate DATE NOT NULL,\
        PRIMARY KEY(uid,mapid,runid,mode,style))\
    "

//
// Create inf_runs table
//
#define QUERY_CREATETABLE_RUNS "\
    CREATE TABLE IF NOT EXISTS "...INF_TABLE_RUNS..." (\
        mapid INT NOT NULL,\
        runid INT NOT NULL,\
        rundata VARCHAR(512),\
        PRIMARY KEY(mapid,runid))\
    "

//
// Create inf_dbver table
//
#define QUERY_CREATETABLE_DBVER "\
    CREATE TABLE IF NOT EXISTS "...INF_TABLE_DBVER..." (\
        id INT NOT NULL UNIQUE,\
        version INT NOT NULL)\
    "



//
// Select all best times for this map
//
#define QUERY_INIT_RECORDS "\
    SELECT \
        _t.uid,\
        runid,\
        mode,\
        style,\
        rectime,\
        name \
    FROM "...INF_TABLE_TIMES..." AS _t INNER JOIN "...INF_TABLE_USERS..." AS _u ON _t.uid=_u.uid WHERE mapid=%i%s \
    AND rectime=(SELECT \
        MIN(rectime) \
        FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style\
    ) \
    ORDER BY runid\
    "

//
// Select all best times of user for this map
//
#define QUERY_INIT_PLAYER_RECORDS "\
    SELECT \
        runid,\
        `mode`,\
        style,\
        rectime \
    FROM "...INF_TABLE_TIMES..." WHERE mapid=%i AND uid=%i ORDER BY runid\
    "
