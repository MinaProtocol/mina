/*
 * Copyright 2022 Google Inc. All Rights Reserved.
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

use js_sys::JsString;
use js_sys::Promise;
use spmc::{channel, Receiver, Sender};
use wasm_bindgen::prelude::*;

static mut THREAD_POOL: Option<rayon::ThreadPool> = None;

pub fn run_in_pool<OP, R>(op: OP) -> R
where
    OP: FnOnce() -> R + Send,
    R: Send,
{
    let pool = unsafe { THREAD_POOL.as_ref().unwrap() };
    pool.install(op)
}

#[wasm_bindgen]
#[doc(hidden)]
pub struct PoolBuilder {
    num_threads: usize,
    sender: Sender<rayon::ThreadBuilder>,
    receiver: Receiver<rayon::ThreadBuilder>,
}

#[cfg(not(feature = "nodejs"))]
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_name = startWorkers)]
    fn start_workers(module: JsValue, memory: JsValue, builder: PoolBuilder) -> Promise;
}
#[cfg(feature = "nodejs")]
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_name = startWorkers)]
    fn start_workers(module: JsString, memory: JsValue, builder: PoolBuilder) -> Promise;
}
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_name = terminateWorkers)]
    fn terminate_workers() -> Promise;
}

#[wasm_bindgen]
impl PoolBuilder {
    fn new(num_threads: usize) -> Self {
        let (sender, receiver) = channel();
        Self {
            num_threads,
            sender,
            receiver,
        }
    }

    #[wasm_bindgen(js_name = numThreads)]
    pub fn num_threads(&self) -> usize {
        self.num_threads
    }

    pub fn receiver(&self) -> *const Receiver<rayon::ThreadBuilder> {
        &self.receiver
    }

    // This should be called by the JS side once all the Workers are spawned.
    // Important: it must take `self` by reference, otherwise
    // `start_worker_thread` will try to receive a message on a moved value.
    pub fn build(&mut self) {
        unsafe {
            THREAD_POOL = Some(
                rayon::ThreadPoolBuilder::new()
                    .num_threads(self.num_threads)
                    // We could use postMessage here instead of Rust channels,
                    // but currently we can't due to a Chrome bug that will cause
                    // the main thread to lock up before it even sends the message:
                    // https://bugs.chromium.org/p/chromium/issues/detail?id=1075645
                    .spawn_handler(move |thread| {
                        // Note: `send` will return an error if there are no receivers.
                        // We can use it because all the threads are spawned and ready to accept
                        // messages by the time we call `build()` to instantiate spawn handler.
                        self.sender.send(thread).unwrap_throw();
                        Ok(())
                    })
                    .build()
                    .unwrap_throw(),
            )
        }
    }
}

#[cfg(feature = "nodejs")]
#[wasm_bindgen(js_name = initThreadPool)]
#[doc(hidden)]
pub fn init_thread_pool(num_threads: usize, worker_source: JsString) -> Promise {
    start_workers(
        worker_source,
        wasm_bindgen::memory(),
        PoolBuilder::new(num_threads),
    )
}

#[cfg(not(feature = "nodejs"))]
#[wasm_bindgen(js_name = initThreadPool)]
#[doc(hidden)]
pub fn init_thread_pool(num_threads: usize) -> Promise {
    start_workers(
        wasm_bindgen::module(),
        wasm_bindgen::memory(),
        PoolBuilder::new(num_threads),
    )
}

#[wasm_bindgen(js_name = exitThreadPool)]
#[doc(hidden)]
pub fn exit_thread_pool() -> Promise {
    unsafe {
        let promise = terminate_workers();
        THREAD_POOL = None;
        promise
    }
}

#[wasm_bindgen]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
#[doc(hidden)]
pub fn wbg_rayon_start_worker(receiver: *const Receiver<rayon::ThreadBuilder>)
where
    // Statically assert that it's safe to accept `Receiver` from another thread.
    Receiver<rayon::ThreadBuilder>: Sync,
{
    // This is safe, because we know it came from a reference to PoolBuilder,
    // allocated on the heap by wasm-bindgen and dropped only once all the
    // threads are running.
    //
    // The only way to violate safety is if someone externally calls
    // `exports.wbg_rayon_start_worker(garbageValue)`, but then no Rust tools
    // would prevent us from issues anyway.
    let receiver = unsafe { &*receiver };
    // Wait for a task (`ThreadBuilder`) on the channel, and, once received,
    // start executing it.
    //
    // On practice this will start running Rayon's internal event loop.
    receiver.recv().unwrap_throw().run();
}
