<?php if (!defined('ABSPATH')) { exit; } $key=aw_current_layout(); ?>
<!doctype html>
<html <?php language_attributes(); ?>>
<head><meta charset="<?php bloginfo('charset'); ?>"><meta name="viewport" content="width=device-width, initial-scale=1"><?php wp_head(); ?></head>
<body <?php body_class($key==='us-station'?'us-station-body':''); ?> <?php if($key==='us-station')echo 'data-surface="flagship"'; ?>>
<?php wp_body_open(); ?>
