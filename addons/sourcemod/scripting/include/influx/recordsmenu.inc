#if defined _influx_recordsmenu_included
    #endinput
#endif
#define _influx_recordsmenu_included


#define INFLUX_LIB_RECORDSMENU      "influx_recordsmenu"


// Displays record menu to client.
native bool Influx_PrintRecords(int client,
                                bool bDisplayAll = false, // Display all records with the parameters you've given. Will bypass run and style category menus.
                                int uid = -1,
                                int mapid = -1, // Will default to current map id if none given.
                                int runid = -1, // If display all is true, will default to client's run id.
                                int mode = -1,
                                int style = -1 );


// When record info is being printed to client.
// Use this to add items onto the menu.
// Item list is max 64 characters. (incl null terminator)
// Look at strafe/jump counter plugin for an example how info is added.
// For button items, check the checkpoint plugin.
forward void Influx_OnPrintRecordInfo( int client, Handle dbres, ArrayList itemlist, Menu menu, int uid, int mapid, int runid, int mode, int style );

// We've pressed a button in the record info menu.
// Use this if you've added button items.
// For an example take a look into the checkpoint plugin.
forward Action Influx_OnRecordInfoButtonPressed( int client, const char[] szInfo );


public SharedPlugin __pl_influx_recordsmenu =
{
    name = INFLUX_LIB_RECORDSMENU,
    file = INFLUX_LIB_RECORDSMENU...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_recordsmenu_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_PrintRecords" );
}
#endif

