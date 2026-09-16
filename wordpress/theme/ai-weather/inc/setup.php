<?php
if (!defined('ABSPATH')) { exit; }
function aw_install_content(){
    if(!current_user_can('manage_options'))return new WP_Error('forbidden','Administrator required.');
    $ids=get_option('aw_page_ids',[]);
    unset($ids['for-media']); // Retired page must never be recreated by the installer.
    foreach(aw_catalog() as $key=>$schema){if($key==='shared'||!empty($ids[$key]))continue;$existing=get_page_by_path($key);if($existing)return new WP_Error('collision','Page slug already exists: '.$key.'. Nothing was overwritten.');}
    // Create page IDs before content so internal links are real WordPress permalinks.
    foreach(aw_catalog() as $key=>$schema){
        if($key==='shared'||!empty($ids[$key]))continue;
        $id=wp_insert_post(['post_type'=>'page','post_status'=>'publish','post_title'=>$schema['title'],'post_name'=>$key,'meta_input'=>['_aw_layout'=>$key]],true);
        if(is_wp_error($id))return $id;$ids[$key]=$id;
    }
    update_option('aw_page_ids',$ids);
    foreach($ids as $key=>$id){if(!get_post_field('post_content',$id))wp_update_post(['ID'=>$id,'post_content'=>wp_slash(aw_seed_content($key))]);}
    if(!get_option('aw_shared_id')){
        $id=wp_insert_post(['post_type'=>'aw_shared','post_status'=>'publish','post_title'=>'Navigation et pied de page — AI Weather','post_content'=>wp_slash(aw_seed_content('shared'))],true);
        if(is_wp_error($id))return $id;update_option('aw_shared_id',$id);
    }
    if(!get_option('aw_previous_front'))update_option('aw_previous_front',['show_on_front'=>get_option('show_on_front'),'page_on_front'=>get_option('page_on_front')]);
    update_option('show_on_front','page');update_option('page_on_front',$ids['home']);
    if(in_array(wp_parse_url(home_url(),PHP_URL_HOST),['neomundi.cloud','www.neomundi.cloud','localhost','127.0.0.1'],true))update_option('blog_public','0');
    return $ids;
}
add_action('admin_menu',function(){add_theme_page('Installation AI Weather','Installation AI Weather','manage_options','aw-setup','aw_setup_screen');});
function aw_setup_screen(){
    if(!current_user_can('manage_options'))return;
    echo '<div class="wrap"><h1>AI Weather — Installation</h1><p>Crée les 11 pages et les contenus Gutenberg. Les pages existantes ne sont jamais écrasées. Configure Home comme accueil. Sur neomundi.cloud : demande aux moteurs de ne pas indexer le staging.</p>';
    if(isset($_POST['aw_install'])){check_admin_referer('aw_install');$result=aw_install_content();echo '<div class="notice '.(is_wp_error($result)?'notice-error':'notice-success').'"><p>'.esc_html(is_wp_error($result)?$result->get_error_message():'Pages prêtes. Modifiez les textes dans Pages, et la navigation/footer dans Apparence.').'</p></div>';}
    echo '<form method="post">';wp_nonce_field('aw_install');submit_button('Préparer les pages AI Weather','primary','aw_install');echo '</form></div>';
}
