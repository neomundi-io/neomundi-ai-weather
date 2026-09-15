<?php
error_reporting(0);
$root=getcwd();if(basename($root)!=='neomundi.cloud')exit(2);
$_SERVER['HTTP_HOST']='neomundi.cloud';$_SERVER['SERVER_NAME']='neomundi.cloud';$_SERVER['HTTPS']='on';$_SERVER['SERVER_PORT']='443';$_SERVER['REQUEST_URI']='/';$_SERVER['REQUEST_METHOD']='GET';
define('DISABLE_WP_CRON',true);define('DISALLOW_FILE_MODS',true);define('WP_USE_THEMES',false);
require $root.'/wp-load.php';
if(home_url()!=='https://neomundi.cloud'||site_url()!=='https://neomundi.cloud')exit(3);
$pages=[];foreach(get_option('aw_page_ids',[]) as $key=>$id){$p=get_post($id);$blocks=parse_blocks($p->post_content);$pages[$key]=['id'=>$id,'layout'=>get_post_meta($id,'_aw_layout',true),'modified'=>$p->post_modified_gmt,'bytes'=>strlen($p->post_content),'blocks'=>array_map(function($b){return ['name'=>$b['blockName'],'attributes'=>$b['attrs'],'children'=>count($b['innerBlocks'])];},$blocks)];}
echo json_encode(['theme'=>get_option('stylesheet'),'front'=>get_option('page_on_front'),'registered'=>WP_Block_Type_Registry::get_instance()->is_registered('ai-weather/layout'),'pages'=>$pages],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES)."\n";
