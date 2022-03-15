/**
 * This file is used to teardown all wasm workers after running the Jest unit tests.
 * When using any signing functionality from the jsoo code, ie. payments, messages, delegation,
 * the jsoo code will spin up wasm workers to accomplish this execution. When the Jest tests are done
 * executing, we need to tear down and clean up these wasm workers by calling 'shutdown()'
 *
 * This only affects the node bindings, shutdown in the context of the browser is a noop.
 */

import { shutdown } from "../src/MinaSigner";
afterAll(() => {
  shutdown();
});
