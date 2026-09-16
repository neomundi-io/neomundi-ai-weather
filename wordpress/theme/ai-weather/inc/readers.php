<?php
if (!defined('ABSPATH')) { exit; }
// Only this appended editorial section reads editable values. Technical markup stays canonical.
function aw_readers_defaults(){return [
 'eyebrow'=>['RESSOURCES','RESOURCES'],
 'title'=>['Pour les journalistes, chercheurs et curieux','For journalists, researchers and curious readers'],
 'intro'=>['AI Weather™ propose une météo du comportement des IA : un point de départ documenté pour comprendre les variations observées, enquêter et poser de nouvelles questions.','AI Weather™ offers a weather report on AI behavior: a documented starting point for understanding observed changes, investigating and asking new questions.'],
 'usage_title'=>['Citer une observation','Citing an observation'],
 'usage'=>['Pour un article ou une étude, accompagnez le signal de sa date de mesure, du système observé et du contexte du protocole. La capsule publiée permet de retrouver le résultat horodaté et son chaînage par hash. Consultez ci-dessus la méthode et les limites avant toute interprétation.','For an article or study, include the measurement date, the observed system and the protocol context alongside the signal. The published capsule provides the timestamped result and its hash chain. Read the methodology and limits above before interpreting it.'],
 'reuse_title'=>['Illustrer et réutiliser','Illustrating and reusing'],
 'reuse'=>['Les widgets embarquables permettent d’illustrer un article avec les mêmes mesures publiques que le site. Le logo ControlTower AI est proposé pour un usage éditorial. Les données JSON, le code public et la méthodologie sont accessibles dans les ressources ci-dessus ; les liens complémentaires suivent.','Embeddable widgets can illustrate an article using the same public measurements as the site. The ControlTower AI logo is available for editorial use. JSON data, public code and methodology are linked in the resources above; additional materials follow.'],
 'capsule_label'=>['Capsule horodatée →','Timestamped capsule →'],
 'widgets_label'=>['Widgets à intégrer →','Embeddable widgets →'],
 'logo_label'=>['Logo éditorial →','Editorial logo →'],
 'method_label'=>['Relire le protocole →','Review the protocol →'],
 'limits_label'=>['Limites de la mesure →','Measurement limits →'],
];}
function aw_readers_urls(){return ['capsule'=>get_theme_file_uri('runtime/aiweather-capsule/latest.json'),'widgets'=>aw_page_url('widgets'),'logo'=>get_theme_file_uri('runtime/assets/logo-controltower.png'),'method'=>'#how-produced','limits'=>'#limits'];}
function aw_readers_render(){
 $saved=get_option('aw_readers_wording',[]);$values=[];
 foreach(aw_readers_defaults() as $key=>$defaults){$values[$key]=[];foreach(['fr','en'] as $i=>$lang)$values[$key][$lang]=$saved[$key.'_'.$lang]??$defaults[$i];}
 $tag=function($tag,$key,$class='')use($values){$v=$values[$key];return '<'.$tag.($class?' class="'.esc_attr($class).'"':'').' data-fr="'.esc_attr($v['fr']).'" data-en="'.esc_attr($v['en']).'">'.esc_html($v['en']).'</'.$tag.'>';};
 $html='<section id="for-readers"><div class="wrap"><div class="section-head center">'.$tag('p','eyebrow','eyebrow center').$tag('h2','title').$tag('p','intro').'</div><div class="aw-reader-copy">'.$tag('h3','usage_title').$tag('p','usage').$tag('h3','reuse_title').$tag('p','reuse').'</div><div class="final-links">';
 foreach(aw_readers_urls() as $key=>$url){$v=$values[$key.'_label'];$url=$saved[$key.'_url']??$url;$html.='<a class="btn btn-ghost" href="'.esc_url($url).'" data-fr="'.esc_attr($v['fr']).'" data-en="'.esc_attr($v['en']).'">'.esc_html($v['en']).'</a>';}
 return $html.'</div></div></section>';
}
add_action('admin_menu',function(){add_theme_page('How It Works — Ressources','How It Works — Ressources','edit_theme_options','aw-readers','aw_readers_admin');});
function aw_readers_admin(){
 if(!current_user_can('edit_theme_options'))return;
 $defaults=aw_readers_defaults();$urls=aw_readers_urls();
 if(isset($_POST['aw_readers_save'])){check_admin_referer('aw_readers_save');$data=[];$input=wp_unslash($_POST['aw_readers']??[]);
 foreach($defaults as $key=>$v)foreach(['fr','en'] as $i=>$lang){$k=$key.'_'.$lang;$data[$k]=sanitize_textarea_field(is_string($input[$k]??null)?$input[$k]:$v[$i]);}
 foreach($urls as $key=>$url){$k=$key.'_url';$candidate=is_string($input[$k]??null)?$input[$k]:$url;$data[$k]=str_starts_with($candidate,'#')?'#'.sanitize_title(substr($candidate,1)):(esc_url_raw($candidate,['https'])?:$url);}
 update_option('aw_readers_wording',$data,false);if(function_exists('wp_cache_clear_cache'))wp_cache_clear_cache();echo '<div class="notice notice-success"><p>Ressources enregistrées.</p></div>';}
 $saved=get_option('aw_readers_wording',[]);
 echo '<div class="wrap"><h1>How It Works — Ressources</h1><p>Ces champs modifient uniquement le bloc final pour les journalistes, chercheurs et curieux. La structure, les widgets et les autres sections restent protégés.</p><form method="post">';wp_nonce_field('aw_readers_save');
 foreach($defaults as $key=>$v){echo '<h2>'.esc_html($key).'</h2>';foreach(['fr','en'] as $i=>$lang){$k=$key.'_'.$lang;echo '<p><label for="'.esc_attr($k).'">'.esc_html(strtoupper($lang).' — '.$key).'</label><br><textarea class="large-text" rows="3" id="'.esc_attr($k).'" name="aw_readers['.esc_attr($k).']">'.esc_textarea($saved[$k]??$v[$i]).'</textarea></p>';}}
 foreach($urls as $key=>$url){$k=$key.'_url';echo '<p><label for="'.esc_attr($k).'">'.esc_html($k).'</label><br><input class="large-text" id="'.esc_attr($k).'" name="aw_readers['.esc_attr($k).']" value="'.esc_attr($saved[$k]??$url).'"></p>';}
 submit_button('Enregistrer les ressources','primary','aw_readers_save');echo '</form></div>';
}
// Retired route: redirect before WordPress canonical redirects and our 200 renderer.
add_action('template_redirect',function(){
 $path=trim((string)wp_parse_url($_SERVER['REQUEST_URI']??'/',PHP_URL_PATH),'/');
 $retired=(int)get_option('aw_retired_for_media_id',0);
 if(preg_match('~^(?:(?:en|fr|es)/)?for-media(?:\.html)?$~',$path)||($retired&&((int)get_queried_object_id()===$retired||(int)($_GET['page_id']??0)===$retired))){wp_safe_redirect(home_url('/how-it-works/'),301,'AI Weather');exit;}
},0);
add_filter('wp_sitemaps_posts_query_args',function($args,$type){if($type==='page'&&($id=(int)get_option('aw_retired_for_media_id',0)))$args['post__not_in']=array_unique(array_merge($args['post__not_in']??[],[$id]));return $args;},10,2);
