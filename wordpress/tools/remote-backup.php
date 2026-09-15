<?php
error_reporting(0);
umask(0077);
$root='/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/sites/neomundi.cloud';
if(realpath('.')!==$root || file_exists('wp-content/themes/ai-weather'))exit("STOP: target changed.\n");
$c=file_get_contents('wp-config.php');$values=[];
foreach(['DB_HOST','DB_NAME','DB_USER','DB_PASSWORD'] as $key){
 $pattern='~define\s*\(\s*([\'"])'.$key.'\1\s*,\s*([\'"])(.*?)\2\s*\)~s';
 if(!preg_match($pattern,$c,$m)||str_contains($m[3],chr(92)))exit("STOP: configuration non literal.\n");
 $values[$key]=$m[3];
}
if(!preg_match('~\$table_prefix\s*=\s*([\'"])([A-Za-z0-9_]+)\1~',$c,$m))exit("STOP: prefix.\n");
try{
 $db=new mysqli($values['DB_HOST'],$values['DB_USER'],$values['DB_PASSWORD'],$values['DB_NAME']);
 $urls=$db->query("SELECT option_name,option_value FROM ".$m[2]."options WHERE option_name IN ('home','siteurl')")->fetch_all(MYSQLI_ASSOC);
 if(count($urls)!==2)throw new Exception();
 foreach($urls as $row)if(parse_url($row['option_value'],PHP_URL_HOST)!=='neomundi.cloud')throw new Exception();
 $backup=dirname($root,2).'/aw-return-'.gmdate('Ymd-His');
 if(!mkdir($backup,0700))throw new Exception();
 $env=getenv();$env['MYSQL_PWD']=$values['DB_PASSWORD'];
 $cmd=['/usr/bin/mysqldump','--single-transaction','--skip-lock-tables','--no-tablespaces','--host='.$values['DB_HOST'],'--user='.$values['DB_USER'],$values['DB_NAME']];
 $p=proc_open($cmd,[0=>['file','/dev/null','r'],1=>['file',$backup.'/database.sql','x'],2=>['file',$backup.'/database-error.log','x']],$pipes,null,$env);
 if(!is_resource($p)||proc_close($p)!==0||filesize($backup.'/database.sql')<100)throw new Exception();
 $p=proc_open(['/bin/tar','-czf',$backup.'/site-before.tar.gz','-C',dirname($root),'neomundi.cloud'],[0=>['file','/dev/null','r'],1=>['file','/dev/null','w'],2=>['file',$backup.'/archive-error.log','x']],$pipes);
 if(!is_resource($p)||proc_close($p)!==0)throw new Exception();
 $manifest=['root'=>$root,'created_utc'=>gmdate('c'),'files'=>[]];
 foreach(['database.sql','site-before.tar.gz'] as $file)$manifest['files'][$file]=['bytes'=>filesize($backup.'/'.$file),'sha256'=>hash_file('sha256',$backup.'/'.$file)];
 foreach(['wp-config.php','.htaccess','.user.ini'] as $file)if(is_file($file))$manifest['preserved'][$file]=hash_file('sha256',$file);
 file_put_contents($backup.'/manifest.json',json_encode($manifest,JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES));
 echo json_encode(['backup'=>$backup,'manifest'=>$manifest],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES)."\n";
}catch(Throwable $e){echo "STOP: backup incomplete; no theme deployment permitted. Details retained privately on hosting.\n";exit(2);}
