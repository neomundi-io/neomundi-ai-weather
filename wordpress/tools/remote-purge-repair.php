<?php
error_reporting(0);
$root=getcwd();if(basename($root)!=='neomundi.cloud')exit(2);
$_SERVER['HTTP_HOST']='neomundi.cloud';$_SERVER['SERVER_NAME']='neomundi.cloud';$_SERVER['HTTPS']='on';$_SERVER['SERVER_PORT']='443';$_SERVER['REQUEST_URI']='/';$_SERVER['REQUEST_METHOD']='GET';
define('DISABLE_WP_CRON',true);define('DISALLOW_FILE_MODS',true);define('WP_USE_THEMES',false);require $root.'/wp-load.php';
if(home_url()!=='https://neomundi.cloud'||site_url()!=='https://neomundi.cloud'||get_option('stylesheet')!=='ai-weather')exit(3);
if(function_exists('wp_cache_clear_cache'))wp_cache_clear_cache();
$pages=[];foreach(get_option('aw_page_ids',[]) as $key=>$id)$pages[$key]=['id'=>$id,'modified_gmt'=>get_post_field('post_modified_gmt',$id),'sha256'=>hash('sha256',get_post_field('post_content',$id))];
echo json_encode(['version'=>wp_get_theme()->get('Version'),'cache'=>'purged','pages'=>$pages],JSON_PRETTY_PRINT)."\n";
