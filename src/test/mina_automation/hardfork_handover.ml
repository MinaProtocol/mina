(** What a test of the hard fork hand-over reads back: the fork config the
    daemon generated, and what the archive made of it. *)

open Core
open Async

(** The config the daemon generated at slot_chain_end, verbatim, and the fork
    it names. *)
let generated_config (daemon_config : Daemon.Config.t) =
  match%bind Daemon.Config.auto_fork_dir daemon_config with
  | None ->
      Deferred.Or_error.error_string "the daemon wrote no auto-fork directory"
  | Some dir ->
      let%map config_json = Reader.file_contents (dir ^/ "daemon.json") in
      let open Or_error.Let_syntax in
      let%bind runtime_config =
        Or_error.try_with (fun () -> Yojson.Safe.from_string config_json)
        >>= fun json ->
        Runtime_config.of_yojson json |> Result.map_error ~f:Error.of_string
      in
      let%map fork =
        Runtime_config.fork runtime_config
        |> Result.of_option
             ~error:(Error.of_string "the generated config names no fork")
      in
      (config_json, fork)

(** The archive's record of a hand-over, read with the archive's own
    queries. *)
module Archive_record = struct
  type t =
    { recorded : (string * string) option
          (** The recorded fork: its state hash and its config, verbatim. *)
    ; fork_block_archived : bool
    ; migration : Archive_lib.Processor.Migration_history.t option
          (** The latest migration. *)
    }
  [@@deriving sexp, compare]

  let load ~postgres_uri ~fork_state_hash =
    Archive_schema.with_connection ~postgres_uri (fun (module Conn) ->
        let open Deferred.Result.Let_syntax in
        let%bind recorded =
          Archive_lib.Processor.Hardfork_state.load_opt (module Conn)
        in
        let%bind fork_block =
          Archive_lib.Processor.Block.find_opt
            (module Conn)
            ~state_hash:
              (Mina_base.State_hash.of_base58_check_exn fork_state_hash)
        in
        let%map migration =
          Archive_lib.Processor.Migration_history.latest_opt (module Conn)
        in
        { recorded =
            Option.map recorded ~f:(fun r -> (r.fork_state_hash, r.config_json))
        ; fork_block_archived = Option.is_some fork_block
        ; migration
        } )
end
