//
// Create inf_cptimes table
//
#define QUERY_CREATETABLE_CPTIMES "\
    CREATE TABLE IF NOT EXISTS "...INF_TABLE_CPTIMES..." (\
        uid INT NOT NULL,\
        mapid INT NOT NULL,\
        runid INT NOT NULL,\
        mode INT NOT NULL,\
        style INT NOT NULL,\
        cpnum INT NOT NULL,\
        cptime REAL NOT NULL,\
        PRIMARY KEY(uid,mapid,runid,mode,style,cpnum))\
    "

//
// Select user's cp times
//
#define QUERY_INIT_USER_CPTIMES "\
    SELECT \
        runid,\
        mode,\
        style,\
        cpnum,\
        cptime \
    FROM "...INF_TABLE_CPTIMES..." AS _cp \
    WHERE uid=%i AND mapid=%i AND \
    cptime=(SELECT \
        MIN(cptime) \
        FROM "...INF_TABLE_CPTIMES..." \
        WHERE \
            uid=_cp.uid \
        AND mapid=_cp.mapid \
        AND runid=_cp.runid \
        AND mode=_cp.mode \
        AND style=_cp.style \
        AND cpnum=_cp.cpnum) \
    GROUP BY runid,mode,style,cpnum \
    ORDER BY runid,cpnum\
    "

//
// Select all best cp times
//
#define QUERY_INIT_BEST_CPTIMES "\
    SELECT \
        `uid`,\
        _cp.runid,\
        _cp.`mode`,\
        _cp.style,\
        _cp.cpnum,\
        cptime \
    FROM "...INF_TABLE_CPTIMES..." as _cp \
    INNER JOIN (SELECT \
            runid,\
            `mode`,\
            style,\
            cpnum,\
            MIN(cptime) AS min_cptime \
        FROM "...INF_TABLE_CPTIMES..." \
        WHERE mapid=%i%s \
        GROUP BY runid,`mode`,style,cpnum \
        ORDER BY runid,cpnum) AS _min \
    ON _cp.runid=_min.runid AND _cp.mode=_min.mode AND _cp.style=_min.style AND _cp.cptime=_min.min_cptime \
    WHERE mapid=%i%s\
    "

//
// Select all server record cp times
//
#define QUERY_INIT_SR_CPTIMES "\
    SELECT \
        _cp.`uid`,\
        _cp.runid,\
        _cp.`mode`,\
        _cp.style,\
        cpnum,\
        cptime \
    FROM "...INF_TABLE_CPTIMES..." AS _cp \
    INNER JOIN (SELECT \
            `uid`,\
            _t.runid,\
            _t.`mode`,\
            _t.style \
        FROM "...INF_TABLE_TIMES..." AS _t \
        INNER JOIN (SELECT \
                runid,\
                `mode`,\
                style,\
                MIN(rectime) AS min_rectime \
            FROM "...INF_TABLE_TIMES..." \
            WHERE mapid=%i%s \
            GROUP BY runid,`mode`,style\
        ) AS _sr \
        ON _t.runid=_sr.runid AND _t.mode=_sr.mode AND _t.style=_sr.style AND _t.rectime=_sr.min_rectime \
        WHERE mapid=%i%s) AS _sr2 \
    ON _cp.uid=_sr2.uid AND _cp.runid=_sr2.runid AND _cp.mode=_sr2.mode AND _cp.style=_sr2.style \
    WHERE mapid=%i%s\
    "
