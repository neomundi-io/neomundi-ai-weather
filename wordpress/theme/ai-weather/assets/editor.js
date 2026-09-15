(function(wp){
  var el=wp.element.createElement;
  wp.hooks.addFilter('blocks.registerBlockType','ai-weather/field',function(settings,name){
    if(['core/paragraph','core/heading','core/button','core/image'].indexOf(name)!==-1)settings.attributes=Object.assign({},settings.attributes,{awField:{type:'string'}});
    return settings;
  });
  wp.blocks.registerBlockType('ai-weather/layout',{
    apiVersion:3,title:'AI Weather — contenus éditoriaux',category:'design',icon:'cloud',
    attributes:{layout:{type:'string',default:'home'}},supports:{html:false,multiple:false,reusable:false,inserter:false},
    edit:function(){return el('div',wp.blockEditor.useBlockProps(),el('p',{style:{padding:'12px',background:'#e8f1ff'}},'Textes, traductions et liens éditables. La vue en liste nomme chaque champ et sa langue. La mise en page et les composants techniques sont protégés. Utilisez Aperçu pour voir le rendu fidèle au site.'),el(wp.blockEditor.InnerBlocks,{templateLock:'all',renderAppender:false,allowedBlocks:['core/paragraph','core/heading','core/button','core/image']}));},
    save:function(){return el(wp.blockEditor.InnerBlocks.Content);}
  });
})(window.wp);
