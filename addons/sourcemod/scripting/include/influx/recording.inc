#if defined _influx_recording_included
    #endinput
#endif
#define _influx_recording_included


#include <influx/core>


#define INFLUX_LIB_RECORDING      "influx_recording"


#define RECORDS_DIR             "influxrecs"


#define RECFLAG_CROUCH      ( 1 << 0 ) // We're crouching.
#define RECFLAG_ATTACK      ( 1 << 1 ) // IN_ATTACK
#define RECFLAG_ATTACK2     ( 1 << 2 ) // IN_ATTACK2
#define RECFLAG_WEP_SLOT1   ( 1 << 3 )
#define RECFLAG_WEP_SLOT2   ( 1 << 4 )
#define RECFLAG_WEP_SLOT3   ( 1 << 5 )
#define RECFLAG_FLASHLIGHT  ( 1 << 6 ) // impulse 100


enum
{
    REC_POS[3],
    REC_ANG[2],
    
    REC_FLAGS,
    
    REC_SIZE
};

/*
#define MAX_RUNREC_WEPNAME          12
#define MAX_RUNREC_WEPNAME_CELL     ( MAX_RUNREC_WEPNAME / 4 )


#define RUNRECFLAG_MODE_PRIM        ( 1 << 0 )
#define RUNRECFLAG_MODE_SEC         ( 1 << 1 )
#define RUNRECFLAG_ZOOM             ( 1 << 2 )
#define RUNRECFLAG_ZOOM2            ( 1 << 3 )
*/

enum
{
    RUNREC_RUN_ID = 0,
    
    RUNREC_REC[MAX_MODES * MAX_STYLES],
    //RUNREC_REC_UID[MAX_MODES * MAX_STYLES],
    RUNREC_REC_TIME[MAX_MODES * MAX_STYLES],
    
    RUNREC_REC_NAME[MAX_MODES * MAX_STYLES * MAX_BEST_NAME_CELL],
    
    //RUNREC_REC_START_PRIMWEP[MAX_MODES * MAX_STYLES * MAX_RUNREC_WEPNAME_CELL],
    //RUNREC_REC_START_SECWEP[MAX_MODES * MAX_STYLES * MAX_RUNREC_WEPNAME_CELL],
    
    //RUNREC_REC_FLAGS[MAX_MODES * MAX_STYLES],
    
    RUNREC_SIZE
};


// 4 byte | "inf!"
#define INF_MAGIC                       0x696e6621

// 4 byte | "v001"
#define INF_RECFILE_CURVERSION          0x76303031

#define MAX_RECFILE_MAPNAME             64
#define MAX_RECFILE_MAPNAME_CELL        MAX_RECFILE_MAPNAME / 4

#define MAX_RECFILE_PLYNAME             32
#define MAX_RECFILE_PLYNAME_CELL        MAX_RECFILE_PLYNAME / 4

enum
{
    RECFILE_MAGIC = 0,
    RECFILE_VERSION,
    RECFILE_HEADERSIZE,
    
    RECFILE_TICKRATE,
    
    RECFILE_TIME,
    RECFILE_RUNID,
    RECFILE_MODE,
    RECFILE_STYLE,
    
    RECFILE_MAPNAME[MAX_RECFILE_MAPNAME_CELL],
    RECFILE_PLYNAME[MAX_RECFILE_PLYNAME_CELL],
    
    RECFILE_FRAMELEN
};

#define INF_CURHEADERSIZE       RECFILE_FRAMELEN


// Return != Plugin_Continue to disable recording for this run.
forward Action Influx_OnRecordingStart( int client );

// Return Plugin_Stop to disable saving this recording. Do not delete the recording handle!
forward Action Influx_OnRecordingFinish( int client, ArrayList hRecording );


native int Influx_GetReplayBot();

native int Influx_GetReplayRunId();
native int Influx_GetReplayMode();
native int Influx_GetReplayStyle();

native float Influx_GetReplayTime();

native float Influx_GetReplayName( char[] out, int len );


public SharedPlugin __pl_influx_recording =
{
    name = INFLUX_LIB_RECORDING,
    file = INFLUX_LIB_RECORDING...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_recording_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_GetReplayBot" );
    MarkNativeAsOptional( "Influx_GetReplayRunId" );
    MarkNativeAsOptional( "Influx_GetReplayMode" );
    MarkNativeAsOptional( "Influx_GetReplayStyle" );
    MarkNativeAsOptional( "Influx_GetReplayTime" );
    MarkNativeAsOptional( "Influx_GetReplayName" );
}
#endif