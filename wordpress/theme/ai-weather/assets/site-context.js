(function(){
  var cfg=window.AW_SITE;if(!cfg)return;
  function configure(){document.querySelectorAll('iframe[src]').forEach(function(frame){
    var raw=frame.getAttribute('src');if(!raw||raw.indexOf(cfg.runtime)!==0)return;
    var u=new URL(raw,location.href);if(u.searchParams.get('site')===cfg.home)return;
    u.searchParams.set('site',cfg.home);frame.src=u.href;
  });}
  new MutationObserver(configure).observe(document.body,{subtree:true,attributes:true,attributeFilter:['src']});configure();
})();
