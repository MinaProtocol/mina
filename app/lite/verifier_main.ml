open Verifier

let () =
  Js_of_ocaml.Worker.set_onmessage (fun (message: Js.js_string Js.t) ->
      let ((chain, _) as query) = Query.of_string (Js.to_string message) in
      let res = verify_chain chain in
      Worker.post_message (Js.string (Response.to_string (query, res))) )
