export let Field;
export let Bool;
export let Circuit;
export let Poseidon;
export let Group;
export let Scalar;

// Import snarky web bindings to include in webpack bundle
import * as Snarky from './chrome_bindings/snarky_js_chrome.bc.js';

(async () => {
  if (typeof window !== 'undefined' && typeof window.document !== 'undefined') {
    Field = window.__snarky.Field;
    Bool = window.__snarky.Bool;
    Circuit = window.__snarky.Circuit;
    Poseidon = window.__snarky.Poseidon;
    Group = window.__snarky.Group;
    Scalar = window.__snarky.Scalar;
  } else {
    Field = Snarky.Field;
    Bool = Snarky.Bool;
    Circuit = Snarky.Circuit;
    Poseidon = Snarky.Poseidon;
    Group = Snarky.Group;
    Scalar = Snarky.Scalar;
  }
})();
