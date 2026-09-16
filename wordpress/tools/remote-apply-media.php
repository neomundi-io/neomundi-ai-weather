<?php
error_reporting(0);umask(0077);
$root='/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/sites/neomundi.cloud';
$backup=dirname($root,2).'/aw-repair-return-20260915-233425';
if(realpath('.')!==$root||!is_file($backup.'/database.sql')||!is_file($backup.'/site-before.tar.gz'))exit(2);
$old=json_decode(base64_decode('@@MANIFEST_BASE64@@'),true);$new=json_decode(base64_decode('@@NEW_MANIFEST_BASE64@@'),true);
$newmap=[];foreach($new['files'] as $f)$newmap[$f['path']]=$f;
$base=$root.'/wp-content/themes/';$changed=[];
foreach($old['files'] as $f){$path=$base.$f['path'];if(!is_file($path)||filesize($path)!==$f['bytes']||hash_file('sha256',$path)!==$f['sha256'])exit("STOP: remote baseline differs.\n");if($newmap[$f['path']]['sha256']!==$f['sha256'])$changed[]=$f['path'];}
$oldpaths=array_column($old['files'],'path');foreach($newmap as $p=>$f)if(!in_array($p,$oldpaths,true)){if(file_exists($base.$p))exit(3);$changed[]=$p;}
if(count($newmap)!==199||!$changed)exit(3);foreach($changed as $p)if(!str_starts_with($p,'ai-weather/')||str_contains($p,'..'))exit(3);
foreach($changed as $p){$file=$backup.'/incoming-media-merge/'.$p;$f=$newmap[$p];if(!is_file($file)||filesize($file)!==$f['bytes']||hash_file('sha256',$file)!==$f['sha256'])exit(4);if(str_ends_with($p,'.php')){$process=proc_open([PHP_BINARY,'-l',$file],[0=>['file','/dev/null','r'],1=>['file','/dev/null','w'],2=>['file','/dev/null','w']],$pipes);if(proc_close($process)!==0)exit(5);}}
foreach($changed as $p){$save=$backup.'/changed-media-merge/'.$p;if(!is_dir(dirname($save)))mkdir(dirname($save),0700,true);if(is_file($base.$p)&&!copy($base.$p,$save))exit(6);}
$applied=[];
try{
 foreach($changed as $p){if(!chmod($backup.'/incoming-media-merge/'.$p,0644)||!rename($backup.'/incoming-media-merge/'.$p,$base.$p))throw new Exception();$applied[]=$p;if(function_exists('opcache_invalidate'))opcache_invalidate($base.$p,true);}
 foreach($new['files'] as $f)if(filesize($base.$f['path'])!==$f['bytes']||hash_file('sha256',$base.$f['path'])!==$f['sha256'])throw new Exception();
}catch(Throwable $e){foreach($applied as $p){if(is_file($backup.'/changed-media-merge/'.$p)){copy($backup.'/changed-media-merge/'.$p,$base.$p);chmod($base.$p,0644);}else{rename($base.$p,$backup.'/incoming-media-merge/'.$p);}}echo "STOP: patch rolled back.\n";exit(7);}
file_put_contents($backup.'/patch-report-media-merge.json',json_encode(['files'=>$changed,'verified'=>count($new['files']),'version'=>$new['version']],JSON_PRETTY_PRINT));
echo json_encode(['replaced'=>$changed,'verified'=>count($new['files']),'version'=>$new['version'],'backup'=>$backup],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES)."\n";
