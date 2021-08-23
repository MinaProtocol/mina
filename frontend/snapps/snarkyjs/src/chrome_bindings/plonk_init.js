import init, * as plonk_wasm from './plonk_wasm.js';
(async () => {
  window.plonk_wasm = plonk_wasm;
  await init();
  plonk_wasm.initThreadPool(navigator.hardwareConcurrency).then(function () {
    var newScript = document.createElement('script');
    newScript.src = './snarkyjs_chrome_bindings.js'; // This is the bundled snarky bindings code -- see webpack.config.js on how the bundle is generated
    document.body.appendChild(newScript);
    newScript.addEventListener('load', () => {
      var newScript = document.createElement('script');
      newScript.src = './snarkyjs_chrome.js'; // This is the bundled snarkyjs code -- see webpack.config.js on how the bundle is generated
      document.body.appendChild(newScript);
    });
  });
})();
