<?php
if (!defined('ABSPATH')) { exit; }
function aw_catalog(){static $data=null;if($data===null)$data=json_decode(file_get_contents(__DIR__.'/catalog.json'),true);return $data;}
function aw_current_layout(){
    if(is_admin())return '';
    $catalog=aw_catalog();$id=get_queried_object_id();
    $slug=$id?get_post_field('post_name',$id):'';
    if($slug!=='shared'&&isset($catalog[$slug]))return $slug;
    if(is_front_page())return 'home';
    // Public routing never depends on Gutenberg blocks or editorial metadata.
    $path=trim((string)wp_parse_url($_SERVER['REQUEST_URI']??'/',PHP_URL_PATH),'/');
    if($path===''||$path==='index.php')return 'home';
    $parts=explode('/',$path);
    if(count($parts)===2&&in_array($parts[0],['en','fr','es'],true))$path=$parts[1];
    $path=preg_replace('/\.html$/','',$path);if($path==='index')$path='home';
    if($path!=='shared'&&isset($catalog[$path]))return $path;
    return '';
}
function aw_page_url($key){$ids=get_option('aw_page_ids',[]);return !empty($ids[$key])?get_permalink($ids[$key]):home_url($key==='home'?'/':'/'.$key.'/');}
function aw_urls($html){
    $html=str_replace(['@@THEME@@','@@RUNTIME@@'],[untrailingslashit(get_template_directory_uri()),get_theme_file_uri('runtime')],$html);
    return preg_replace_callback('/@@PAGE:([a-z-]+)@@/',function($m){return aw_page_url($m[1]);},$html);
}
function aw_values($blocks){
    $values=[];
    foreach($blocks as $b){
        $key=$b['attrs']['awField']??'';
        if($key){
            $html=$b['innerHTML']??'';
            if(in_array($b['blockName'],['core/button','core/image'],true)){
                $tags=new WP_HTML_Tag_Processor($html);$tag=$b['blockName']==='core/image'?'IMG':'A';
                if($tags->next_tag($tag))$values[$key]=(string)$tags->get_attribute($tag==='IMG'?'src':'href');
            }else{
                // Keep intentional spaces around mixed prose/emphasis; strip all editor markup.
                if(preg_match('/<(?:p|h[1-6])(?:\s[^>]*)?>([\s\S]*?)<\/(?:p|h[1-6])>/', $html, $m))$html=$m[1];
                $values[$key]=html_entity_decode(strip_tags($html),ENT_QUOTES|ENT_HTML5,'UTF-8');
            }
        }
        $values=array_merge($values,aw_values($b['innerBlocks']??[]));
    }
    return $values;
}
function aw_page_values(){return [];}
function aw_render_layout($key,$blocks){
    $catalog=aw_catalog();if(!isset($catalog[$key])||$key==='shared')return '';
    // Phase 1: saved editorial fields are retained in the database but are never
    // used in public output. Canonical HTML is the only visual/content authority.
    $html=file_get_contents(get_theme_file_path('templates/'.$key.'.html'));
    $html=preg_replace_callback('/@@PART:([a-z-]+)@@/',function($m){$file=get_theme_file_path('template-parts/'.$m[1].'.html');return is_file($file)?file_get_contents($file):'';},$html);
    return aw_urls($html);
}
function aw_seed_content($key){
    $schema=aw_catalog()[$key];$blocks=[];
    foreach($schema['fields'] as $f){
        $attrs=['awField'=>$f['key'],'metadata'=>['name'=>($f['lang']??'') . ' — '.$f['label']],'lock'=>['move'=>true,'remove'=>true]];
        $value=aw_urls($f['value']);
        if($f['kind']==='url'){
            $block='core/button';$html='<div class="wp-block-button"><a class="wp-block-button__link wp-element-button" href="'.esc_url($value).'">'.esc_html($f['label']).'</a></div>';
        }elseif($f['kind']==='image'){
            $block='core/image';$html='<figure class="wp-block-image"><img src="'.esc_url($value).'" alt=""/></figure>';
        }elseif($f['kind']==='heading'){$block='core/heading';$attrs['level']=2;$html='<h2 class="wp-block-heading">'.esc_html($value).'</h2>';}
        else{$block='core/paragraph';$html='<p>'.esc_html($value).'</p>';}
        $blocks[]=['blockName'=>$block,'attrs'=>$attrs,'innerBlocks'=>[],'innerHTML'=>$html,'innerContent'=>[$html]];
    }
    return serialize_block(['blockName'=>'ai-weather/layout','attrs'=>['layout'=>$key,'lock'=>['move'=>true,'remove'=>true]],'innerBlocks'=>$blocks,'innerHTML'=>'','innerContent'=>array_fill(0,count($blocks),null)]);
}
