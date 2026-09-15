<?php
error_reporting(E_ALL);
$root='/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/sites/neomundi.cloud';
if(realpath('.')!==$root)exit(2);
$manifest=json_decode(base64_decode('@@MANIFEST_BASE64@@'),true);
$base=$root.'/wp-content/themes/';$expected=[];$errors=[];
foreach($manifest['files'] as $f){$p=$base.$f['path'];$expected[]=$f['path'];if(!is_file($p)||filesize($p)!==$f['bytes']||hash_file('sha256',$p)!==$f['sha256'])$errors[]=$f['path'];}
$actual=[];foreach(new RecursiveIteratorIterator(new RecursiveDirectoryIterator($base.'ai-weather',FilesystemIterator::SKIP_DOTS)) as $f)if($f->isFile())$actual[]=substr($f->getPathname(),strlen($base));
sort($actual);sort($expected);
$return=dirname($root,2).'/aw-return-20260915-201008';
$before=json_decode(file_get_contents($return.'/manifest.json'),true);
$preserved=[];foreach($before['preserved'] as $p=>$hash)$preserved[$p]=hash_file('sha256',$root.'/'.$p)===$hash;
echo json_encode(['verified_count'=>count($expected),'actual_count'=>count($actual),'exact_file_set'=>$actual===$expected,'mismatches'=>$errors,'preserved'=>$preserved],JSON_PRETTY_PRINT)."\n";
if($errors||$actual!==$expected||in_array(false,$preserved,true))exit(3);
