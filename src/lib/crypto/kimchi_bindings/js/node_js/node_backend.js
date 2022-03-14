/* workerHelpers.no-modules.js */

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

// Provides: worker_threads
var worker_threads = require("worker_threads");

// Note: this is never used, but necessary to prevent a bug in Firefox
// (https://bugzilla.mozilla.org/show_bug.cgi?id=1702191) where it collects
// Web Workers that have a shared WebAssembly memory with the main thread,
// but are not explicitly rooted via a `Worker` instance.
//
// By storing them in a variable, we can keep `Worker` objects around and
// prevent them from getting GC-d.

// Provides: _workers
var _workers;

// Provides: wasm_ready
// Requires: worker_threads
var wasm_ready = function(wasm) {
    worker_threads.parentPort.postMessage({ type: 'wasm_bindgen_worker_ready' });
    wasm.wbg_rayon_start_worker(worker_threads.workerData.receiver);
};

// Provides: startWorkers
// Requires: worker_threads, _workers, caml_js_export_var
var startWorkers = (function() {
    var snarky_ready_resolve;
    caml_js_export_var().snarky_ready =
        new joo_global_object.Promise(function(resolve) {
            snarky_ready_resolve = resolve;
        });
    return function(worker_source, memory, builder) {
        joo_global_object.wasm_workers = [];
        joo_global_object.wasm_rayon_poolbuilder = builder;
        return joo_global_object.Promise.all(
            Array.from({ length: builder.numThreads() }, function() {
                // Self-spawn into a new Worker.
                // The script is fetched as a blob so it works even if this script is
                // hosted remotely (e.g. on a CDN). This avoids a cross-origin
                // security error.
                var worker = new worker_threads.Worker(worker_source, {
                    workerData: {memory: memory, receiver: builder.receiver()}
                });
                joo_global_object.wasm_workers.push(worker);
                var target = worker;
                var type = 'wasm_bindgen_worker_ready';
                return new joo_global_object.Promise(function(resolve) {
                    var done = false;
                    target.on('message', function onMsg(data) {
                        if (data == null || data.type !== type || done) return;
                        done = true;
                        resolve(worker);
                    });
                });
            })
        ).then(function(data) {
            snarky_ready_resolve();
            _workers = data;
            try { builder.build(); }
            catch (_e) {
                // We 'mute' this error here, since it can only ever throw when
                // there is something wrong with the rayon subsystem in WASM, and
                // we deliberately introduce such a problem by destroying builder
                // when we want to shutdown the process (and thus need to kill the
                // child threads). The error here won't be useful to developers
                // using the library.
            }
        });
    };
})();

/* node_backend.js */

// Provides: plonk_wasm
// Requires: worker_threads, startWorkers, wasm_ready
var plonk_wasm = (function() {
    // Expose this globally so that it can be referenced from WASM.
    joo_global_object.startWorkers = startWorkers;
    var env = require("env");
    if (worker_threads.isMainThread) {
        env.memory =
            new joo_global_object.WebAssembly.Memory({
                initial: 20,
                maximum: 65536,
                shared: true});
        joo_global_object.startWorkers = startWorkers;
    } else {
        env.memory = worker_threads.workerData.memory;
    }
    var plonk_wasm = require("./plonk_wasm.js");
    // TODO: This shouldn't live here.
    // TODO: js_of_ocaml is unhappy about __filename here, but it's in the
    // global scope, yet not attached to the global object, so we can't access
    // it differently.
    if (worker_threads.isMainThread) {
        plonk_wasm.initThreadPool(3, __filename);
    } else {
        wasm_ready(plonk_wasm);
    }
    return plonk_wasm;
})();
