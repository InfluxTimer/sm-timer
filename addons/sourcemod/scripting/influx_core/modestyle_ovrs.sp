enum
{
    MOVR_NAME_ID[MAX_SAFENAME_CELL] = 0,
    MOVR_ID,
    
    MOVR_ORDER,
    MOVR_OVRNAME[MAX_MODE_NAME_CELL],
    MOVR_OVRSHORTNAME[MAX_MODE_SHORTNAME_CELL],
    
    MOVR_USEADMFLAGS,
    MOVR_ADMFLAGS,
    
    MOVR_SIZE
};

enum
{
    SOVR_NAME_ID[MAX_SAFENAME_CELL] = 0,
    SOVR_ID,
    
    SOVR_ORDER,
    SOVR_OVRNAME[MAX_STYLE_NAME_CELL],
    SOVR_OVRSHORTNAME[MAX_STYLE_SHORTNAME_CELL],
    
    SOVR_USEADMFLAGS,
    SOVR_ADMFLAGS,
    
    SOVR_SIZE
};


ArrayList g_hModeOvers;
ArrayList g_hStyleOvers;


static void _Sort( int[] ids, int[] orders, int num )
{
    int i, j;
    
    bool bFinished = true;
    
    do
    {
        bFinished = true;
        
        for ( i = 0; i < num; i++ )
        {
            j = i + 1;
            
            if ( j >= num )
            {
                break;
            }
            
            if ( orders[j] > orders[i] )
            {
                int temp;

                temp = orders[j];
                orders[j] = orders[i];
                orders[i] = temp;
                
                temp = ids[j];
                ids[j] = ids[i];
                ids[i] = temp;
                
                
                bFinished = false;
            }
        }
    }
    while ( !bFinished );
}

static int _Find( ArrayList overs, int id_index, int invalid_id, int id, const char[] sz = "", bool bUpdateId = false )
{
    int len = overs.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( id != invalid_id && overs.Get( i, id_index ) == id )
        {
            return i;
        }
        
        if ( sz[0] )
        {
            char temp[32];
            overs.GetString( i, temp, sizeof( temp ) );
            
            if ( StrEqual( sz, temp, false ) )
            {
                if ( bUpdateId ) overs.Set( i, id, id_index );
                
                return i;
            }
        }
    }

    return -1;
}

stock int FindModeOver( int id = MODE_INVALID, const char[] sz = "", bool bUpdateId = false )
{
    return _Find( g_hModeOvers, MOVR_ID, MODE_INVALID, id, sz, bUpdateId );
}

stock void SortModesArray()
{
    int nModes = g_hModes.Length;
    
    if ( nModes < 2 ) return;
    
    
    int[] ids = new int[nModes]; 
    
    SortModeIds( ids, nModes );
    
    
    for ( int i = 0; i < nModes; i++ )
    {
        int index = FindModeById( ids[i] );
        
        if ( index == -1 ) continue;
        
        if ( i == index ) continue;
        
        
        g_hModes.SwapAt( index, i );
    }
}

stock void SortModeIds( int[] ids, int nModes )
{
    int len = g_hModes.Length;
    
    if ( len != nModes ) return;
    
    
    int[] orders = new int[nModes];
    
    decl String:name[32];
    
    for ( int i = 0; i < len; i++ )
    {
        int id = g_hModes.Get( i, MODE_ID );
        
        GetModeSafeNameByIndex( i, name, sizeof( name ) );
        
        int j = FindModeOver( id, name, true );
        
        
        orders[i] = ( j != -1 ) ? g_hModeOvers.Get( j, MOVR_ORDER ) : 0;
        ids[i] = id;
    }
    
    _Sort( ids, orders, nModes );
}

stock void SetModeOverrides( int index )
{
    decl String:name[32];
    GetModeSafeNameByIndex( index, name, sizeof( name ) );
    
    int j = FindModeOver( g_hModes.Get( index, MODE_ID ), name, true );
    
    if ( j == -1 ) return;
    
    
    char test[2];
    
    decl data[MOVR_SIZE];
    g_hModeOvers.GetArray( j, data );
    
    test[0] = view_as<char>( data[MOVR_OVRNAME] );
    if ( test[0] != 0 )
    {
        SetModeNameByIndex( index, view_as<char>( data[MOVR_OVRNAME] ) );
    }
    
    test[0] = view_as<char>( data[MOVR_OVRSHORTNAME] );
    if ( test[0] != 0 )
    {
        SetModeShortNameByIndex( index, view_as<char>( data[MOVR_OVRSHORTNAME] ) );
    }
    
    if ( data[MOVR_USEADMFLAGS] )
    {
        g_hModes.Set( index, data[MOVR_ADMFLAGS], MODE_ADMFLAGS );
    }
}

stock int FindStyleOver( int id = STYLE_INVALID, const char[] sz = "", bool bUpdateId = false )
{
    return _Find( g_hStyleOvers, SOVR_ID, STYLE_INVALID, id, sz, bUpdateId );
}

stock void SortStyleIds( int[] ids, int nStyles )
{
    int len = g_hStyles.Length;
    
    if ( len != nStyles ) return;
    
    
    int[] orders = new int[nStyles];
    
    decl String:name[32];
    
    for ( int i = 0; i < len; i++ )
    {
        int id = g_hStyles.Get( i, STYLE_ID );
        
        GetStyleSafeNameByIndex( i, name, sizeof( name ) );
        
        int j = FindStyleOver( id, name, true );
        
        
        orders[i] = ( j != -1 ) ? g_hStyleOvers.Get( j, SOVR_ORDER ) : 0;
        ids[i] = id;
    }
    
    _Sort( ids, orders, nStyles );
}

stock void SortStylesArray()
{
    int nStyles = g_hStyles.Length;
    
    if ( nStyles < 2 ) return;
    
    
    int[] ids = new int[nStyles]; 
    
    SortStyleIds( ids, nStyles );
    
    
    for ( int i = 0; i < nStyles; i++ )
    {
        int index = FindStyleById( ids[i] );
        
        if ( index == -1 ) continue;
        
        if ( i == index ) continue;
        
        
        g_hStyles.SwapAt( index, i );
    }
}

stock void SetStyleOverrides( int index )
{
    decl String:name[32];
    GetStyleSafeNameByIndex( index, name, sizeof( name ) );
    
    int j = FindStyleOver( g_hStyles.Get( index, STYLE_ID ), name, true );
    
    if ( j == -1 ) return;
    
    
    char test[2];
    
    decl data[SOVR_SIZE];
    g_hStyleOvers.GetArray( j, data );
    
    test[0] = view_as<char>( data[SOVR_OVRNAME] );
    if ( test[0] != 0 )
    {
        SetStyleNameByIndex( index, view_as<char>( data[SOVR_OVRNAME] ) );
    }
    
    
    test[0] = view_as<char>( data[SOVR_OVRSHORTNAME] );
    if ( test[0] != 0 )
    {
        SetStyleShortNameByIndex( index, view_as<char>( data[SOVR_OVRSHORTNAME] ) );
    }
    
    if ( data[SOVR_USEADMFLAGS] )
    {
        g_hStyles.Set( index, data[SOVR_ADMFLAGS], STYLE_ADMFLAGS );
    }
}
