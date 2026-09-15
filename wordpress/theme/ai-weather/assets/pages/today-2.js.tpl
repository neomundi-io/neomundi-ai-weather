
(function () {
  if (window.parent === window) return;
  var lastHeight = 0;
  function reportHeight() {
    var height = Math.ceil(document.body.getBoundingClientRect().height);
    if (height === lastHeight) return;
    lastHeight = height;
    window.parent.postMessage({ type: "nm-today-resize", height: height }, "*");
  }
  new ResizeObserver(reportHeight).observe(document.body);
  window.addEventListener("load", reportHeight);
})();
