open Core_kernel

let s3_link = "https://s3-us-west-2.amazonaws.com/o1labs-snarkette-data"

let get url on_success on_error =
  let req = XmlHttpRequest.create () in
  req##.onerror :=
    Dom.handler (fun _e ->
        on_error (Error.of_string "get request failed") ;
        Js._false ) ;
  req##.onload :=
    Dom.handler (fun _e ->
        ( match Js.Opt.to_option (File.CoerceTo.string req##.response) with
        | None -> on_error (Error.of_string "get request failed")
        | Some s -> on_success (Js.to_string s) ) ;
        Js._false ) ;
  req##_open (Js.string "GET") (Js.string url) Js._true ;
  req##send Js.Opt.empty
