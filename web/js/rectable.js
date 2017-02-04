var g_curRecOff = 0;

function clickRecTable( btn, tblname, dir, list )
{
	var table = document.getElementById( tblname );
	if ( table == null ) return;
	
	
	if ( typeof table.curRecordOffset === 'undefined' )
	{
		table.curRecordOffset = 0;
	}
	
	var rows = table.getElementsByClassName( 'rectable-data-row' );
	if ( rows == null ) return;
	
	
	var form = new FormData();
	form.append( 'offset', table.curRecordOffset + dir );
	form.append( 'num', rows.length );
	form.append( 'type', tblname );
	
	
	var steamid = getURLParamByName( 'u' );
	if ( steamid != null )
	{
		form.append( 'steamid', steamid );
	}
	
	var mapname = getURLParamByName( 'm' );
	if ( mapname != null )
	{
		form.append( 'mapname', mapname );
	}
	
	var search = getURLParamByName( 'q' );
	if ( search != null )
	{
		form.append( 'search', search );
	}
	
	
	var http = new XMLHttpRequest();
	http.onreadystatechange = function()
	{
		if ( http.readyState != 4 || http.status != 200 ) return;
		
		
		var res = http.responseText;
		if ( !res ) // No response, just disable our button.
		{
			btn.disabled = true;
			return;
		}
		
		try { res = JSON.parse( http.responseText ); }
		catch ( e ){ console.log( 'Something went wrong: ' + http.responseText ); return; }
		
		
		var btns = table.getElementsByClassName( 'rectable-nav' );
		
		
		var columns = table.getElementsByClassName( 'rectable-column-name' );
		if ( columns != null )
		{
			for ( var i = 0; i < columns.length; i++ )
			{
				setElementTxtFancy( columns[i], columns[i].innerHTML, 1.0 );
			}
		}
		
		for ( var i = 0; i < rows.length; i++ )
		{
			var values = rows[i].getElementsByClassName( 'rectable-data-value' );
			
			if ( res.length > i )
			{
				var j = 0;
				list.forEach( function( key ) {
					setElementTxtFancy( values[j], res[i][key], 1.0 );
					++j;
				} );
			}
			else
			{
				for ( var j = 0; j < values.length; j++ )
				{
					setElementTxtFancy( values[j], '', 1.0 );
				}
				
				btns[0].disabled = false;
				btns[1].disabled = true;
			}
		}
		
		table.curRecordOffset += dir;
		
		if ( table.curRecordOffset <= 0 )
		{
			btns[0].disabled = true;
		}
		
		if ( dir > 0 )
		{
			btns[0].disabled = false;
		}
		else
		{
			btns[1].disabled = false;
		}
	};
	
	http.open( 'POST', 'ajax/rectable.php', true );
	http.send( form );
}