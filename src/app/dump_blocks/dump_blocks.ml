open Core
open Full_frontier.For_tests

(* NOTE: This type is initially instantiated as Encoding.t io, where
   Encoding.t is a simple placeholder for encoding format. Then this
   placeholder is replaced with a module holding actual encoding
   functions encapsulated in a value of type 'a codec (see below).
   Choice of the actual codec module depends on more than one CLI
   argument, which is why it must be delayed until all the CLI
   arguments are parsed. This choice is made by mk_io function below. *)
type 'a io = { encoding : 'a; filename : string }

type 'a codec = (module Encoding.S with type t = 'a)

type conf = Conf : 'a codec io option * 'a codec io list -> conf

let mk_io : type a. a Encoding.content -> Encoding.t io -> a codec io =
 fun content io ->
  let open Encoding in
  { io with
    encoding =
      ( match (content, io.encoding) with
      | Precomputed, Sexp ->
          (module Sexp_precomputed)
      | Precomputed, Json ->
          (module Json_precomputed)
      | Precomputed, Binary ->
          (module Binary_precomputed)
      | Block, Sexp ->
          (module Sexp_block)
      | Block, Json ->
          failwith "Json encoding for full blocks not supported."
      | Block, Binary ->
          (module Binary_block) )
  }

let encoded_block =
  Command.Arg_type.create (fun s ->
      match String.split ~on:':' s with
      | [ encoding; filename ] ->
          { encoding =
              ( match String.lowercase encoding with
              | "sexp" ->
                  Encoding.Sexp
              | "json" ->
                  Json
              | "bin" | "binary" ->
                  Binary
              | _ ->
                  failwith "invalid encoding" )
          ; filename
          }
      | _ ->
          failwith "invalid format" )

let () =
  let open Core_kernel in
  Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true

let logger = Logger.create ()

let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

let constraint_constants = precomputed_values.constraint_constants

let output_block : type a. a -> a codec io -> unit =
 fun content { encoding; filename } ->
  let module Enc : Encoding.S with type t = a = (val encoding) in
  let channel =
    match filename with "-" -> Out_channel.stdout | s -> Out_channel.create s
  in
  fprintf channel "%s" (Enc.to_string content) ;
  match filename with "-" -> () | _ -> Out_channel.close channel

(* This executable outputs random block to stderr in sexp and json
   The output is useful for src/lib/mina_block tests when the sexp/json representation changes. *)
(* TODO make generation more feauture-rich:
   * include snark works
   * include all types of transactions
   * etc.
*)
let f (type a) ?parent (outputs : a codec io list) make_breadcrumb =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let frontier = create_frontier () in
      let root = Full_frontier.root frontier in
      let open Async_kernel.Deferred.Let_syntax in
      let%map breadcrumb = make_breadcrumb root in
      List.iter outputs ~f:(fun output ->
          let module Enc = (val output.encoding) in
          let content =
            Enc.of_breadcrumb ?with_parent_statehash:parent breadcrumb
          in
          eprintf
            !"Randomly generated block, %s: %s\n"
            Enc.name
            (match output.filename with "-" -> "" | s -> s) ;
          output_block content output ) ;
      clean_up_persistent_root ~frontier )

let default_outputs =
  [ { encoding = Encoding.Sexp; filename = "-" }
  ; { encoding = Encoding.Json; filename = "-" }
  ]

let command =
  Command.basic
    ~summary:"Transcribe between block formats or generate a random block"
    (let%map_open.Command outputs =
       flag "-o" (listed encoded_block)
         ~doc:
           "output <format>:<path>; formats are: sexp / json / bin; a dash (-) \
            denotes stdout (example: -o json:-)"
     and input =
       flag "-i" (optional encoded_block)
         ~doc:
           "input <format>:<path>; formats are: sexp / json / bin; a dash (-) \
            denotes stdin (example: -i json:-)"
     and full =
       flag "--full" no_arg ~doc:"use full blocks, not just precomputed values"
     and parent =
       flag "--parent" (optional string) ~aliases:[ "--parent-statehash" ]
         ~doc:"statehash of the parent block"
     in
     let outs = match outputs with [] -> default_outputs | _ -> outputs in
     let conf =
       if full then
         Conf
           ( Option.map input ~f:(mk_io Block)
           , List.map ~f:(mk_io Encoding.Block) outs )
       else
         Conf
           ( Option.map input ~f:(mk_io Precomputed)
           , List.map ~f:(mk_io Encoding.Precomputed) outs )
     in
     fun () ->
       match conf with
       | Conf (None, outs) ->
           let verifier = verifier () in
           Core_kernel.Quickcheck.test
             (gen_breadcrumb ~verifier ())
             ~trials:1 ~f:(f ?parent outs)
       | Conf (Some { encoding; filename }, outs) ->
           let module Enc = (val encoding) in
           let input =
             match filename with
             | "-" ->
                 In_channel.stdin
             | s ->
                 In_channel.create s
           in
           let contents = In_channel.input_all input |> Enc.of_string in
           List.iter outs ~f:(output_block contents) )

let () = Command_unix.run command
