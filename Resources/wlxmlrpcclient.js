jQuery(document).ready(function() {				
	jQuery('.notebook-expression').addClass('white colorTipContainer').append('<span class="colorTip" style="margin-left: -60px;"><span class="content">Copy input</span><span class="pointyTipShadow"></span><span class="pointyTip"></span></span>');
				
	jQuery('.colorTipContainer').hover(
		function() {
			jQuery(this).find('.colorTip').show();
	},
		function() {
			jQuery(this).find('.colorTip').hide().find('.content').text('Copy input');
	});

	jQuery('.colorTipContainer').click(function() {
		jQuery(this).find('.colorTip .content').text('Copied!');
		jQuery(this).find('textarea').css('display', 'block').select();
		document.execCommand('copy');
		jQuery(this).find('textarea').css('display', 'none');
	});
});