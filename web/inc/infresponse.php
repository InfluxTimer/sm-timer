<?php
class InfAjaxResponse_RecTable
{
	private $cols = array();
	
	function __construct() {}
	
	public function addColumn( $name, $func )
	{
		$pos = count( $this->cols );
		
		$this->cols[$pos] = array();
		$this->cols[$pos]['key'] = $name;
		$this->cols[$pos]['func'] = $func;
	}
	
	public function respond( $values )
	{
		if ( !is_array( $values ) ) return;
		
		
		$arr = array();
		
		foreach ( $values as $row )
		{
			$pos = count( $arr );
			
			$arr[$pos] = array();
			
			foreach ( $this->cols as $col )
			{
				$arr[$pos][$col['key']] = $col['func']( $row );
			}
		}
		
		echo json_encode( $arr );
	}
}
?>