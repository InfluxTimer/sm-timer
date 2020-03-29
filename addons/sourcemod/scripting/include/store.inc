#if defined _store_included
	#endinput
#endif
#define _store_included

new g_cvarChatTag = -1;
#define CHAT_TAG g_eCvars[g_cvarChatTag][sCache]

#define ITEM_NAME_LENGTH 64
#define STORE_MAX_ITEMS 2048
#define STORE_MAX_HANDLERS 64
#define STORE_MAX_PLANS 8
#define STORE_MAX_SLOTS 4

enum struct Item_Plan
{
	char szName[ITEM_NAME_LENGTH];
	int iPrice;
	int iTime;
}

enum struct Store_Item
{
	char szName[ITEM_NAME_LENGTH];
	char szUniqueId[PLATFORM_MAX_PATH];
	char szShortcut[64];
	int iId;
	int iPrice;
	int iParent;
	int iHandler;
	int iFlagBits;
	int iData;
	int iPlans;
	bool bBuyable;
	bool bIgnoreVIP;
	Handle hAttributes;
}

enum struct Type_Handler
{
	char szType[64];
	char szUniqueKey[32];
	bool bEquipable;
	bool bRaw;
	Handle hPlugin;
	Function fnMapStart;
	Function fnReset;
	Function fnConfig;
	Function fnUse;
	Function fnRemove;
}

enum struct Client_Item
{
	int iId;
	int iUniqueId;
	bool bSynced;
	bool bDeleted;
	int iDateOfPurchase;
	int iDateOfExpiration;
	int iPriceOfPurchase;
}

native Store_RegisterHandler(String:type[], String:uniquekey[], Function:mapstart, Function:reset, Function:config, Function:use, Function:remove, bool:equipable = true, bool:raw = false);
native Store_RegisterMenuHandler(String:identifier[], Function:menu, Function:handler);
native Store_SetDataIndex(itemid, index);
native Store_GetDataIndex(itemid);
native Store_GetEquippedItem(client, String:type[], slot=0);
native Store_IsClientLoaded(client);
native Store_DisplayPreviousMenu(client);
native Store_SetClientMenu(client, num);
native Store_GetClientCredits(client);
native Store_SetClientCredits(client, credits);
native Store_IsClientVIP(client);
native Store_IsItemInBoughtPackage(client, itemid, uid=-1);
native Store_ShouldConfirm();
native Store_DisplayConfirmMenu(client, String:title[], Function:callback, data);
//native Store_GetItem(itemid, Store_Item output);
//native Store_GetHandler(index, Type_Handler output);
native Store_GiveItem(client, itemid, purchase=0, expiration=0, price=0);
native Store_RemoveItem(client, itemid);
//native Store_GetClientItem(client, itemid, Client_Item output);
native Store_GetClientTarget(client);
native Store_GiveClientItem(client, recipient, itemid);
native Store_HasClientItem(client, itemid);
native Store_IterateEquippedItems(client, &start, bool:attributes=false);

forward Store_OnClientModelChanged(client, String:model[]);

public Extension:__ext_store_sm =
{
	name = "Store - The Resurrection",
	file = "store_sm.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
	required = 0,
};
