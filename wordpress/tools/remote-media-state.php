<?php
error_reporting(0);umask(0077);
$root='/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/sites/neomundi.cloud';$backup=dirname($root,2).'/aw-repair-return-20260915-233425';
if(realpath('.')!==$root||!is_file($backup.'/database.sql'))exit(2);
$_SERVER['HTTP_HOST']='neomundi.cloud';$_SERVER['SERVER_NAME']='neomundi.cloud';$_SERVER['HTTPS']='on';$_SERVER['SERVER_PORT']='443';$_SERVER['REQUEST_URI']='/';$_SERVER['REQUEST_METHOD']='GET';
define('DISABLE_WP_CRON',true);define('DISALLOW_FILE_MODS',true);define('WP_USE_THEMES',false);require $root.'/wp-load.php';
if(home_url()!=='https://neomundi.cloud'||site_url()!=='https://neomundi.cloud'||get_option('stylesheet')!=='ai-weather'||!function_exists('aw_readers_render'))exit(3);
$ids=get_option('aw_page_ids',[]);$id=$ids['for-media']??0;$post=get_post($id);if(!$post||$post->post_name!=='for-media'||$post->post_type!=='page'||$post->post_status!=='publish')exit(4);
$admins=get_users(['role'=>'administrator','number'=>1,'fields'=>'ID']);if(!$admins)exit(5);wp_set_current_user($admins[0]);
$menus=[];foreach(get_posts(['post_type'=>'nav_menu_item','post_status'=>'any','numberposts'=>-1]) as $item){$url=get_post_meta($item->ID,'_menu_item_url',true);if((int)get_post_meta($item->ID,'_menu_item_object_id',true)===$id||preg_match('~(?:^|/)for-media(?:/|\.html|$)~',$url))$menus[]=['post'=>$item,'meta'=>get_post_meta($item->ID)];}
$snapshot=['page'=>$post,'meta'=>get_post_meta($id),'page_ids'=>$ids,'menus'=>$menus,'readers_wording'=>get_option('aw_readers_wording',null)];
$file=$backup.'/for-media-before.json';if(file_exists($file)||!file_put_contents($file,wp_json_encode($snapshot,JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE)))exit(6);
copy(get_theme_file_path('templates/for-media.html'),$backup.'/for-media-canonical.html');
try{
 if(!wp_trash_post($id)||get_post_status($id)!=='trash')throw new Exception();
 foreach($menus as $item){$r=wp_update_post(['ID'=>$item['post']->ID,'post_status'=>'draft'],true);if(is_wp_error($r))throw new Exception();}
 update_option('aw_retired_for_media_id',$id,false);unset($ids['for-media']);update_option('aw_page_ids',$ids);
 if(function_exists('wp_cache_clear_cache'))wp_cache_clear_cache();
 echo wp_json_encode(['page_id'=>$id,'page_status'=>get_post_status($id),'saved_content'=>$file,'menu_items_archived'=>count($menus),'cache'=>'purged','polylang_language'=>function_exists('pll_get_post_language')?pll_get_post_language($id):null,'editable_fields'=>count(aw_readers_defaults())*2+count(aw_readers_urls())],JSON_PRETTY_PRINT)."\n";
}catch(Throwable $e){wp_untrash_post($id);wp_update_post(['ID'=>$id,'post_status'=>$post->post_status,'post_name'=>'for-media']);update_option('aw_page_ids',$snapshot['page_ids']);foreach($menus as $item)wp_update_post(['ID'=>$item['post']->ID,'post_status'=>$item['post']->post_status]);if(function_exists('wp_cache_clear_cache'))wp_cache_clear_cache();exit("STOP: WordPress mutation rolled back.\n");}
