#include <sourcemod>

#include <influx/core>
#include <influx/recordsmenu>

#include <msharedutil/misc>



//#define DEBUG_DB


// Print records CallBack (PCB)

#define MAX_PCB_PLYNAME             32
#define MAX_PCB_PLYNAME_CELL        MAX_PCB_PLYNAME / 4

#define PCB_NUM_ELEMENTS            7 // This is for menu string parsing.

enum
{
    PCB_USERID = 0,
    
    PCB_UID,
    PCB_MAPID,
    PCB_RUNID,
    PCB_MODE,
    PCB_STYLE,
    PCB_OFFSET,
    PCB_TOTALRECORDS,
    
    
    // For now ignore player names
    //PCB_PLYNAME[MAX_PCB_PLYNAME_CELL],
    //PCB_MAPNAME[], // Map name is not necessary since we ALWAYS retrieve the map id.
    
    PCB_SIZE
};


float g_flLastRecPrintTime[INF_MAXPLAYERS];


// FORWARDS
Handle g_hForward_OnPrintRecordInfo;
Handle g_hForward_OnRecordInfoButtonPressed;


// CONVARS
ConVar g_ConVar_DisplayFullListMax;


#include "influx_recordsmenu/cmds.sp"
#include "influx_recordsmenu/db.sp"
#include "influx_recordsmenu/db_cb.sp"
#include "influx_recordsmenu/menus_hndlrs.sp"

public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Records Menu",
    description = "Displays record menu with !top/!wr/!mytop commands.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_RECORDSMENU );
    
    
    // NATIVES
    CreateNative( "Influx_PrintRecords", Native_PrintRecords );
    
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    // FORWARDS
    g_hForward_OnPrintRecordInfo = CreateGlobalForward( "Influx_OnPrintRecordInfo", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell );
    g_hForward_OnRecordInfoButtonPressed = CreateGlobalForward( "Influx_OnRecordInfoButtonPressed", ET_Hook, Param_Cell, Param_String );
    
    
    // CONVARS
    g_ConVar_DisplayFullListMax = CreateConVar( "influx_recordsmenu_displayfulllistmax", "6", "If the number of records to print is less than this, full list is displayed. Otherwise, display style menu.", FCVAR_NOTIFY, true, 0.0, false, 0.0 );
    
    AutoExecConfig( true, "recordsmenu", "influx" );
    
    
    // RECORD CMDS
    RegConsoleCmd( "sm_top", Cmd_PrintRecords );
    RegConsoleCmd( "sm_worldrecords", Cmd_PrintRecords );
    RegConsoleCmd( "sm_worldrecord", Cmd_PrintRecords );
    RegConsoleCmd( "sm_wr", Cmd_PrintRecords );
    RegConsoleCmd( "sm_records", Cmd_PrintRecords );
    
    RegConsoleCmd( "sm_myrecords", Cmd_PrintMyRecords );
    RegConsoleCmd( "sm_myrecord", Cmd_PrintMyRecords );
    RegConsoleCmd( "sm_myrec", Cmd_PrintMyRecords );
    RegConsoleCmd( "sm_mytop", Cmd_PrintMyRecords );
    RegConsoleCmd( "sm_mywr", Cmd_PrintMyRecords );
    
    RegConsoleCmd( "sm_mymaps", Cmd_PrintMyMapsRecords );
    RegConsoleCmd( "sm_mytopmaps", Cmd_PrintMyMapsRecords );
    RegConsoleCmd( "sm_mytopmap", Cmd_PrintMyMapsRecords );
    RegConsoleCmd( "sm_mywrmaps", Cmd_PrintMyMapsRecords );
    RegConsoleCmd( "sm_mywrmap", Cmd_PrintMyMapsRecords );
    
    RegConsoleCmd( "sm_wrmaps", Cmd_PrintMapsRecords );
    RegConsoleCmd( "sm_wrmap", Cmd_PrintMapsRecords );
    RegConsoleCmd( "sm_topmaps", Cmd_PrintMapsRecords );
    RegConsoleCmd( "sm_topmap", Cmd_PrintMapsRecords );
}

public void OnClientPutInServer( int client )
{
    g_flLastRecPrintTime[client] = 0.0;
}

stock void RunIdToName( int runid, int mapid = -1, char[] out, int len )
{
    if ( mapid == Influx_GetCurrentMapId() )
    {
        Influx_GetRunName( runid, out, len );
        return;
    }
    
    
    if ( runid == MAIN_RUN_ID )
    {
        strcopy( out, len, "Main" );
    }
    else // Display the id at least.
    {
        FormatEx( out, len, "Run (ID: %i)", runid );
    }
}

// NATIVES
public int Native_PrintRecords( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    if ( Inf_HandleCmdSpam( client, 3.0, g_flLastRecPrintTime[client], true ) )
    {
        return 0;
    }
    
    
    bool bForceDisplay = GetNativeCell( 2 );
    
    int uid = GetNativeCell( 3 );
    int mapid = GetNativeCell( 4 );
    int runid = GetNativeCell( 5 );
    int mode = GetNativeCell( 6 );
    int style = GetNativeCell( 7 );
    
    if ( runid < 1 )
        runid = Influx_GetClientRunId( client );
    
    if ( bForceDisplay )
    {
        if ( mapid < 1 )
            mapid = Influx_GetCurrentMapId();
                
        DB_PrintRecords( client, uid, mapid, runid, mode, style );
        
        return 1;
    }
    
    
    DB_DetermineRunMenu( client, uid, mapid > 0 ? mapid : Influx_GetCurrentMapId(), runid );
    
    return 1;
}
