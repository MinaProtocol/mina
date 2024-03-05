open Core
open Frontier_base
open Full_frontier.For_tests

type encoding = Sexp | Json

let encoding_to_string = function
  | Sexp -> "sexp"
  | Json -> "json"

type block =
  { encoding : encoding
  ; filename : string
  }

let encoded_block =
  Command.Arg_type.create (fun s ->
      match String.split ~on:':' s with
      | [ encoding; filename ] ->
          { encoding=
              ( match String.lowercase encoding with
              | "sexp" -> Sexp
              | "json" -> Json
              | _ -> failwith "invalid encoding" )
          ; filename
          }
      | _ -> failwith "invalid format" )

let () =
  let open Core_kernel in
  Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true

let logger = Logger.create ()

let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

let constraint_constants = precomputed_values.constraint_constants

let output_block precomputed { encoding; filename } =
  let channel =
    match filename with
    | "-" -> Out_channel.stdout
    | s -> Out_channel.create s
  in
  let contents =
    match encoding with
    | Sexp -> Sexp.to_string (Mina_block.Precomputed.sexp_of_t precomputed)
    | Json -> Yojson.Safe.to_string (Mina_block.Precomputed.to_yojson precomputed)
  in
  eprintf !"Randomly generated block, %s: %s\n"
    (encoding_to_string encoding)
    (match filename with "-" -> "" | s -> s) ;
  fprintf channel "%s\n" contents ;
  match filename with
    | "-" -> ()
    | s -> Out_channel.close channel

(* This executable outputs random block to stderr in sexp and json
   The output is useful for src/lib/mina_block tests when the sexp/json representation changes. *)
(* TODO make generation more feauture-rich:
   * include snark works
   * include all types of transactions
   * etc.
*)
let f outputs make_breadcrumb =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let frontier = create_frontier () in
      let root = Full_frontier.root frontier in
      let open Async_kernel.Deferred.Let_syntax in
      let%map breadcrumb = make_breadcrumb root in
      let block = Breadcrumb.block breadcrumb in
      let staged_ledger =
        Transition_frontier.Breadcrumb.staged_ledger breadcrumb
      in
      let scheduled_time =
        Mina_block.(Header.protocol_state @@ header block)
        |> Mina_state.Protocol_state.blockchain_state
        |> Mina_state.Blockchain_state.timestamp
      in
      let precomputed =
        Mina_block.Precomputed.of_block ~logger ~constraint_constants
          ~staged_ledger ~scheduled_time
          (Breadcrumb.block_with_hash breadcrumb)
      in
      List.iter outputs ~f:(output_block precomputed);
      clean_up_persistent_root ~frontier )

let default_outputs =
  [ { encoding= Sexp; filename= "-" }
  ; { encoding= Json; filename= "-" }
  ]

let command =
  Command.basic
    ~summary:"Transcribe between block formats or generate a random block"
    (let%map_open.Command outputs =
       flag
         "-o"
         (listed encoded_block)
         ~doc:"output <format>:<path>; formats are: sexp / json / bin; a dash (-) dentoes stdout"
     and input =
       flag
         "-i"
         (optional encoded_block)
         ~doc:"input <format>:<path>; formats are: sexp / json / bin; a dash (-) dentoes stdin"
     in
     let outs = match outputs with
       | [] -> default_outputs
       | _ -> outputs
     in
     fun () ->
     match input with
     | None ->
        let verifier = verifier () in
        Core_kernel.Quickcheck.test (gen_breadcrumb ~verifier ()) ~trials:1 ~f:(f outs)
     | Some { encoding; filename } ->
        let input =
          match filename with
          | "-" -> In_channel.stdin
          | s -> In_channel.create s
        in
        let contents = In_channel.input_all input in
        let precomputed =
          match encoding with
          | Sexp -> 
             Sexp.of_string contents
             |> Mina_block.Precomputed.t_of_sexp
          | Json ->
             Yojson.Safe.from_string contents
             |> Mina_block.Precomputed.of_yojson
             |> Result.map_error ~f:(fun s -> Failure s)
             |> Result.ok_exn
        in
        List.iter outputs ~f:(output_block precomputed))

let () = Command_unix.run command

