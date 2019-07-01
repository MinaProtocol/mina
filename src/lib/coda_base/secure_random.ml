open Core
open Async.Deferred.Let_syntax

let urandom = lazy (Async_unix.Reader.open_file "/dev/urandom")

let string () = 
    let%bind urandom = Lazy.force urandom in
    let bytes = Bytes.make 128 '\x00' in
    match%map Async_unix.Reader.really_read urandom bytes ~len:128 with
    | `Ok -> Bytes.to_string bytes
    | `Eof count -> failwithf "EOF reading /dev/urandom. Wanted 128 bytes, got %d" count ()
