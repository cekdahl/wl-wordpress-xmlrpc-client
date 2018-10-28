<?php

function wl_xml_rpc_client_enqueue_resources() {	
	wp_register_style('wlxmlrpcclient_css', trailingslashit(get_stylesheet_directory_uri()).'style.css', false, '1.0.0', 'screen');
	wp_enqueue_style('wlxmlrpcclient_css');
	
	wp_register_script('wlxmlrpcclient_js',  trailingslashit(get_stylesheet_directory_uri()).'wlxmlrpcclient.js', array('jquery'), '1.0.0', true);
	wp_enqueue_script('wlxmlrpcclient_js');
}

add_action('wp_enqueue_scripts', 'wl_xml_rpc_client_enqueue_resources');

remove_filter('the_content', 'wptexturize');
remove_filter('comment_text', 'wptexturize');
remove_filter('the_excerpt', 'wptexturize');
remove_filter( 'the_content', 'wpautop', 99 );
remove_filter( 'the_excerpt', 'wpautop', 99 );

?>