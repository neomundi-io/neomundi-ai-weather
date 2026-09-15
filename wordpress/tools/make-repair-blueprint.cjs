const fs=require('fs'),path=require('path');const root=path.resolve(__dirname,'..');
const fixture=fs.readFileSync(path.join(__dirname,'repair-regression-plugin.php'),'utf8');
const bp={preferredVersions:{php:'8.3',wp:'6.6'},landingPage:'/',login:true,steps:[{step:'writeFile',path:'/wordpress/wp-content/mu-plugins/aw-local-regression.php',data:fixture},{step:'activateTheme',themeFolderName:'ai-weather'},{step:'runPHP',code:"<?php require '/wordpress/wp-load.php'; wp_set_current_user(1); update_option('permalink_structure','/%postname%/'); $r=aw_install_content(); if(is_wp_error($r))throw new Exception($r->get_error_message()); flush_rewrite_rules();"}]};
fs.writeFileSync(path.join(root,'test-results/repair/blueprint.json'),JSON.stringify(bp,null,2));
