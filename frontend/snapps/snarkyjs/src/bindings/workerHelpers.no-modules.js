/**
 * Copyright 2021 Google Inc. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *     http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// This file is kept similar to workerHelpers.js, but intended to be used in
// a module-less ES module environment (which has a few differences).

const {
  Worker, isMainThread, parentPort, workerData
} = require('worker_threads');

if (!isMainThread) {

module.exports.memory = workerData.memory;
module.exports.receiver = workerData.receiver;
module.exports.wasm_ready = function(wasm) {
    parentPort.postMessage({ type: 'wasm_bindgen_worker_ready' });
    wasm.wbg_rayon_start_worker(workerData.receiver);
};

} else { // isMainThread

function waitForMsgType(target, type) {
  return new Promise(resolve => {
    var done = false;
    target.on('message', function onMsg(data) {
      if (data == null || data.type !== type || done) return;
      done = true;
      resolve(data);
    });
  });
}

// Note: this is never used, but necessary to prevent a bug in Firefox
// (https://bugzilla.mozilla.org/show_bug.cgi?id=1702191) where it collects
// Web Workers that have a shared WebAssembly memory with the main thread,
// but are not explicitly rooted via a `Worker` instance.
//
// By storing them in a variable, we can keep `Worker` objects around and
// prevent them from getting GC-d.
let _workers;

module.exports.startWorkers = async function startWorkers(worker_source, memory, builder) {
  _workers = await Promise.all(
    Array.from({ length: builder.numThreads() }, async () => {
      // Self-spawn into a new Worker.
      // The script is fetched as a blob so it works even if this script is
      // hosted remotely (e.g. on a CDN). This avoids a cross-origin
      // security error.
      const worker = new Worker(worker_source, {
        workerData: {memory, receiver: builder.receiver()}
      });
      await waitForMsgType(worker, 'wasm_bindgen_worker_ready');
      return worker;
    })
  );
  builder.build();
}

module.exports.wasm_ready = function(_wasm) { };

}
