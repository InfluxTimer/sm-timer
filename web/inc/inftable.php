<?php
$GLOBALS['inftable_inc_js'] = true;


class InfRecordTable
{
	protected $name;
	protected $limit;
	
	protected $id;
	protected $class;
	
	protected $cols = array();
	
	private $draw_nav = false;
	private $ajaxkeys = false;
	
	protected $func_drawrow = null;
	
	function __construct( $name, $id = '', $class = '', $limit = 0 )
	{
		$this->name = $name;
		$this->limit = $limit;
		
		$this->id = $id;
		$this->class = $class;
	}
	
	public function addColumn( $head, $func )
	{
		$i = count( $this->cols );
		
		$this->cols[$i] = array();
		$this->cols[$i]['name'] = $head;
		$this->cols[$i]['func'] = $func;
	}
	
	public function output( $values )
	{
		if ( is_array( $values ) )
		{
			$this->outputFinal( $values );
		}
		else
		{
			$this->createTable();
			
			$this->createHead();
			$this->createHeaders();
			
			echo '<tr><td colspan="' . count( $this->cols ) . '">' . $values . '</td></tr>';
			
			$this->finishTable();
		}
	}
	
	protected function createHead() { echo '<tr><th class="rectable-head" colspan="' . count( $this->cols ) . '">' . $this->name . '</th></tr>'; }
	
	protected function createTable()
	{ 
		echo '<table class="rectable' . ($this->class != '' ? (' ' . $this->class) : '') . '" id="' . $this->id . '" border="0" cellspacing="0" cellpadding="0">';
	}
	
	protected function finishTable() { echo '</table>'; }
	
	public function setDrawNav( $b, $ajaxkey_array = false )
	{
		$this->draw_nav = $b;
		
		if ( $ajaxkey_array )
		{
			$keys = '';
			
			foreach ( $ajaxkey_array as $key )
			{
				$keys .= ( $keys != '' ? ',' : '' ) . '\'' . $key . '\'';
			}
			
			$this->ajaxkeys = $keys;
		}
	}
	
	private function createNav()
	{
		if ( !$this->draw_nav ) return;
		
		
		// Include our javascript to query more records.
		if ( $GLOBALS['inftable_inc_js'] )
		{
			$GLOBALS['inftable_inc_js'] = false;
			
			echo '<script type="text/javascript" src="js/rectable.js"></script>';
		}
		
		
		echo '<tr class="rectable-nav-container"><td class="rectable-nav-container" colspan="' . count( $this->cols ) . '">';
		
		echo '<button onclick="clickRecTable(this,\'' . $this->id . '\',-1,[' . $this->ajaxkeys . ']);" class="rectable-nav" disabled>&lt;&lt;</button>';
		echo '<button onclick="clickRecTable(this,\'' . $this->id . '\',1,[' . $this->ajaxkeys . ']);" class="rectable-nav">&gt;&gt;</button>';
		
		echo '</td></tr>';
	}
	
	protected function createHeaders()
	{	
		echo '<tr>';
		
		foreach ( $this->cols as $col )
		{
			echo '<th class="rectable-column-name">' . $col['name'] . '</th>';
		}
		
		echo '</tr>';
	}
	
	public function setDrawRowFunc( $func )
	{
		$this->func_drawrow = $func;
	}
	
	protected function shouldDrawRow( $value )
	{
		$func = $this->func_drawrow;
		return ( $func == null || $func( $value ) != false ) ? true : false;
	}
	
	protected function outputFinal( $values )
	{
		$this->createTable();
		
		if ( count( $this->cols ) )
		{
			$this->createHead();
		}
		
		$this->createHeaders();
		
		
		$num = 0;
		
		foreach ( $values as $row )
		{
			if ( $this->limit > 0 && $num >= $this->limit )
			{
				break;
			}
			
			
			if ( $this->shouldDrawRow( $row ) )
			{
				echo '<tr class="rectable-data-row">';
				
				foreach ( $this->cols as $col )
				{
					echo '<td class="rectable-data-value">' . $col['func']( $row ) . '</td>';
				}
				
				echo '</tr>';
				
				++$num;
			}
		}
		
		
		$this->createNav();
		
		$this->finishTable();
	}
}

class InfInfoTable extends InfRecordTable
{
	protected function createHead() { echo '<tr class="rectable-head"><th class="rectable-head" colspan="2">' . $this->name . '</th></tr>'; }
	
	protected function outputFinal( $values )
	{
		$this->createTable();
		
		if ( count( $this->cols ) )
		{
			$this->createHead();
		}
		
		foreach ( $this->cols as $col )
		{
			echo '<tr><th>' . $col['name'] . '</th><td class="rectable-data-value">' . $col['func']( $values ) . '</td></tr>';
		}
		
		
		$this->finishTable();
	}
}
?>