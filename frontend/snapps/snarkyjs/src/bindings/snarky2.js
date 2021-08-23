export let Field;
export let Bool;
export let Circuit;
export let Poseidon;
export let Group;
export let Scalar;

import * as Snarky from "../../chrome_test/snarky_js_chrome.bc"

(async () => {
if (typeof window !== 'undefined' && typeof window.document !== 'undefined') {
  Field = window.__snarky.Field;
  Bool = window.__snarky.Bool;
  Circuit = window.__snarky.Circuit;
  Poseidon = window.__snarky.Poseidon;
  Group = window.__snarky.Group;
  Scalar = window.__snarky.Scalar;
} else {
  Field = Snarky.Field
  Bool = Snarky.Bool;
  Circuit = Snarky.Circuit;
  Poseidon = Snarky.Poseidon;
  Group = Snarky.Group;
  Scalar = Snarky.Scalar;
}
})()