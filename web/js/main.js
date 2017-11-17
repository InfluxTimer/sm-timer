'use strict';
function getURLParamByName( name )
{
	const url = window.location.href;
	
	name = name.replace( /[\[\]]/g, '\\$&' );
	
	const regex = new RegExp( '[?&]' + name + '(=([^&#]*)|&|#|$)' );
	const res = regex.exec( url );
	
	if ( !res ) return null;
	
	if ( !res[2] ) return '';
	
	return decodeURIComponent( res[2].replace( /\+/g, ' ' ) );
}

function timerFancyTxt( element, txt, rate, nexttime, stop )
{
	let opacity = parseFloat( element.style.opacity );
	
	if ( !stop && opacity <= 0.0 )
	{
		element.innerHTML = txt;
		
		stop = true;
		rate = -rate;
		
		// We're done. No need to set opacity.
		if ( txt == '' )
		{
			element.fncyTimer = null;
			return;
		}
	}
	
	opacity = opacity + rate;
	
	element.style.opacity = opacity + rate;
	
	
	if ( stop && opacity >= 1.0 )
	{
		element.fncyTimer = null;
		return;
	}
	
	element.fncyTimer = setTimeout( timerFancyTxt, nexttime, element, txt, rate, nexttime, stop );
}

function setElementTxtFancy( element, txt, time )
{
	// Elements by default may not have opacity set.
	element.style.opacity = '1.0';
	
	const framerate = ( 1.0 / 18.0 );
	const nexttime = framerate * 1000.0;
	
	const rate = -(framerate / time) * 2.0;
	
	if ( element.fncyTimer != null )
	{
		clearTimeout( element.fncyTimer );
	}
	
	element.fncyTimer = setTimeout( timerFancyTxt, nexttime, element, txt, rate, nexttime, false );
}
