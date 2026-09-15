<?php
// Local Playground only. Never included in the installable theme.
if(!in_array($_SERVER['HTTP_HOST']??'',['127.0.0.1:9402','localhost:9402'],true))return;
if(($_GET['aw_regression']??'')==='resilient'){
 add_action('send_headers',function(){header('X-AW-Regression: resilient');});
 add_action('template_redirect',function(){
  header('X-AW-Block-Registered: '.(WP_Block_Type_Registry::get_instance()->is_registered('ai-weather/layout')?'1':'0'));
  header('X-AW-Layout-Meta: '.(get_post_meta(get_queried_object_id(),'_aw_layout',true)===''?'missing':'present'));
  $blocks=parse_blocks(get_post_field('post_content',get_queried_object_id()));header('X-AW-Root-Block: '.($blocks[0]['blockName']??'none'));
 });
 add_action('init',function(){unregister_block_type('ai-weather/layout');},999);
 add_filter('get_post_metadata',function($value,$id,$key){return $key==='_aw_layout'?'':$value;},10,3);
 add_filter('the_posts',function($posts){foreach($posts as $p){$blocks=parse_blocks($p->post_content);if(($blocks[0]['blockName']??'')==='ai-weather/layout'){$p->post_content=serialize_blocks($blocks[0]['innerBlocks']);wp_cache_set($p->ID,$p,'posts');}}return $posts;});
}
