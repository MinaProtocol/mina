type 'a js_promise

external to_js : 'a Promise.t -> 'a js_promise = "deferred_to_promise"

external of_js : 'a js_promise -> 'a Promise.t = "deferred_of_promise"
