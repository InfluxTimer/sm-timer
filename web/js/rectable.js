'use strict';
let g_curRecOff = 0;

function clickRecTable( btn, tblname, dir, list )
{
	const table = document.getElementById( tblname );
	if ( table == null ) return;
	
	
	if ( typeof table.curRecordOffset === 'undefined' )
	{
		table.curRecordOffset = 0;
	}
	
	const rows = table.getElementsByClassName( 'rectable-data-row' );
	if ( rows == null ) return;
	
	
	const form = new FormData();
	form.append( 'offset', table.curRecordOffset + dir );
	form.append( 'num', rows.length );
	form.append( 'type', tblname );
	
	
	const steamid = getURLParamByName( 'u' );
	if ( steamid != null )
	{
		form.append( 'steamid', steamid );
	}
	
	const mapname = getURLParamByName( 'm' );
	if ( mapname != null )
	{
		form.append( 'mapname', mapname );
	}
	
	const search = getURLParamByName( 'q' );
	if ( search != null )
	{
		form.append( 'search', search );
	}
	
	// Disable button so we don't accidentally click it while waiting for the server.
	btn.disabled = true;
	
	const http = new XMLHttpRequest();
	http.onreadystatechange = function()
	{
		if ( http.readyState != 4 || http.status != 200 ) return;
		
		
		let res = http.responseText;
		if ( !res ) // No response.
			return;
		
		try { res = JSON.parse( http.responseText ); }
		catch ( e ) { console.log( 'Something went wrong: ' + http.responseText ); return; }
		
		
		btn.disabled = false;
		
		const btns = table.getElementsByClassName( 'rectable-nav' );
		
		const btnback = btns[0];
		const btnfwd = btns[1];
		
		//const columns = table.getElementsByClassName( 'rectable-column-name' );
		//if ( columns != null )
		//{
		//	for ( const col of columns )
		//	{
		//		setElementTxtFancy( col, col.innerHTML, 1.0 );
		//	}
		//}
		
		for ( let i = 0; i < rows.length; i++ )
		{
			const values = rows[i].getElementsByClassName( 'rectable-data-value' );
			
			if ( res.length > i )
			{
				let j = 0;
				list.forEach( function( key ) {
					setElementTxtFancy( values[j], res[i][key], 1.0 );
					++j;
				} );
			}
			else
			{
				// We don't have any more values, just set to nothing.
				for ( const col of values )
				{
					setElementTxtFancy( col, '', 1.0 );
				}
				
				btnback.disabled = false;
				btnfwd.disabled = true;
			}
		}
		
		table.curRecordOffset += dir;
		
		
		if ( dir > 0 )
		{
			btnback.disabled = false;
		}
		else
		{
			btnfwd.disabled = false;
		}
		
		if ( table.curRecordOffset <= 0 )
		{
			btnback.disabled = true;
		}
	};
	
	http.open( 'POST', 'ajax/rectable.php', true );
	http.send( form );
}
