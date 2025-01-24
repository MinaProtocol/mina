(* Cache proofs using the filesystem, one file per proof. *)

open Core
open Async

let counter = ref 0

module Make (B: sig include Binable.S end) = struct 

  (** Root folder *)
  
  type t = string

  type id = { idx : int }

  let initialize path = 
    let logger = Logger.create () in
    match%bind Sys.is_directory path with
        | `Yes ->
          let%bind () = File_system.remove_dir path in 
          Deferred.Result.return (path)
        | `No -> 
            (match%bind Sys.is_file path with 
              | `Yes -> 
                let%bind () = File_system.remove_dir path in 
                Deferred.Result.return (path)
              | `No -> 
                [%log error] "Cannot evaluate existence of cache folder"
                ~metadata:[ ("path", `String path) ] ;
                failwithf "Cannot evaluate existence of cache folder'%s'" path ()
                      
              | `Unknown -> 
                [%log error] "Cannot evaluate existence of cache folder"
                ~metadata:[ ("path", `String path) ] ;
                failwithf "Cannot evaluate existence of cache folder'%s'" path ()
            )
        | `Unknown -> 
          [%log error] "Cannot evaluate existence of cache folder"
          ~metadata:[ ("path", `String path) ] ;
          failwithf "Cannot evaluate existence of cache folder'%s'" path ()

  let path t i = t ^ Filename.dir_sep ^ Int.to_string i

  let get t (id:id) : B.t  =
    (* Read from the file. *)
    In_channel.with_file ~binary:true (path t id.idx) ~f:(fun chan ->
        let str = In_channel.input_all chan in
        Binable.of_string
          (module B)
          str )

  let put t x : id =
    let new_counter = !counter in
    incr counter ;
    let res = { idx = new_counter } in
    (* When this reference is GC'd, delete the file. *)
    Core.Gc.Expert.add_finalizer_last_exn res (fun () ->
        Core.Unix.unlink (path t new_counter) ) ;
    (* Write the proof to the file. *)
    Out_channel.with_file ~binary:true (path t new_counter) ~f:(fun chan ->
        Out_channel.output_string chan
        @@ Binable.to_string
            (module B)
            x ) ;
    res
end