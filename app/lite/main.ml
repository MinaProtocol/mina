open Core_kernel
open Js_of_ocaml
open Lite_base

let rest_server_port = 8080

let url s = sprintf "http://localhost:%d/%s" rest_server_port s

let get url on_success on_error =
  let req = XmlHttpRequest.create () in
  req ##. onerror :=
    Dom.handler (fun _e ->
        on_error (Error.of_string "get request failed") ;
        Js._false ) ;
  req ##. onload :=
    Dom.handler (fun _e ->
        ( match Js.Opt.to_option (File.CoerceTo.string req ##. response) with
        | None -> on_error (Error.of_string "get request failed")
        | Some s -> on_success s ) ;
        Js._false ) ;
  req ## _open (Js.string "GET") (Js.string url) Js._true ;
  req ## send Js.Opt.empty

let get_account pk on_sucess on_error =
  let url =
    sprintf "/account?public_key=%s"
      (B64.encode (Binable.to_string (module Public_key.Compressed) pk))
  in
  get url on_sucess on_error

let () =
  Printf.printf
    !"%{sexp:Lite_base.Account.Nonce.t}\n"
    Lite_base.Account.Nonce.one
