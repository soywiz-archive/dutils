<?php
	$gheader = "module si;\n\n";
	$gdata = '';
	$gend = '';
	$imports = array();
	
	function process_imports($i) {
		global $imports;
		//print_r($i);
		
		$protection = trim($i[1]);
		$list = $i[2];
		if (!strlen($protection)) $protection = 'public';
		foreach (explode(',', $list) as $e) { $e = trim($e);
			if (isset($imports[$e])) {
				if ($protection != 'public') continue;
			}
			$imports[$e] = $protection;
		}
		
		return '';
	}
	
	function process_file($rf) {
		global $gdata;
		$data = file_get_contents($rf);
		$data = preg_replace('/module[^;]+;/Umsi', '', $data, -1, $count);
		$data = preg_replace_callback('/(public|private)?\\s*import\\s+([^;]+);/Umsi', 'process_imports', $data, -1);
		//$data = preg_replace('/import[^;]+;/Umsi', 'process_imports', $data, -1);
		//echo "$count\n";
		$gdata .= "\n" . $data;
	}
	process_file('../si.d');
	foreach (scandir($path = '../') as $f) { $rf = "{$path}/{$f}";
		if (!preg_match('/^si_(.*)\\.d$/Umsi', $f)) continue;
		process_file($rf);
	}
	
	unset($imports['si']);
	
	foreach ($imports as $im => $priv) {
		$gheader .= "{$priv} import {$im};\n";
	}
	
	//$gend = 'void main() { }';
	
	file_put_contents('../single/si.d', "{$gheader}\n\n" . trim($gdata) . $gend);
?>