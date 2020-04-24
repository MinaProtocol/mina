[%%import
"/src/config.mlh"]

open Core_kernel
open Module_version

let genesis_timestamp_of_string str =
  let default_timezone = Core.Time.Zone.of_utc_offset ~hours:(-8) in
  Core.Time.of_string_gen ~if_no_timezone:(`Use_this_one default_timezone) str

let validate_time time_str =
  match
    Result.try_with (fun () ->
        Option.value_map ~default:(Time.now ()) ~f:genesis_timestamp_of_string
          time_str )
  with
  | Ok time ->
      Ok time
  | Error _ ->
      Error
        "Expected a timestamp of the form \"%Y-%m-%d  %H:%M:%S%z\". For \
         example, \"2019-01-30 12:00:00-0800\" for UTC-08:00 timezone"

module Accounts = struct
  module Account = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { balance: int
          ; public_key: (string option[@default None])
          ; private_key: (string option[@default None])
          ; delegate: (string option[@default None]) }
        [@@deriving yojson]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t =
      { balance: int
      ; public_key: (string option[@default None])
      ; private_key: (string option[@default None])
      ; delegate: (string option[@default None])}
    [@@deriving yojson]
  end

  type account = Account.t =
    {balance: int; public_key: string option; private_key: string option; delegate: string option}

  type account_list = Account.t list [@@deriving yojson]

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Named of string | Accounts of Account.Stable.V1.t list
      [@@deriving yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t = Named of string | Accounts of Account.t list
  [@@deriving yojson]

  let from_file filename =
    Accounts
      ( Yojson.Safe.from_file filename
      |> account_list_of_yojson |> Result.ok_or_failwith )

  let to_file filename accounts =
    Yojson.Safe.to_file filename (account_list_to_yojson accounts)

  let from_file_flag =
    let open Command in
    let open Let_syntax in
    let%map_open accounts_file =
      Param.flag "--accounts-file"
        ~doc:
          "filename Use the accounts listed in the file to populate the \
           genesis ledger"
        (Flag.optional Param.string)
    in
    Option.map ~f:from_file accounts_file

  let from_name_flag =
    let open Command in
    let open Let_syntax in
    let%map_open name =
      Param.flag "--genesis-ledger"
        ~doc:"ledger-name Use the named genesis ledger"
        (Flag.optional Param.string)
    in
    Option.map name ~f:(fun name -> Named name)

  let from_flags =
    Core_kernel.Command.Param.choose_one ~if_nothing_chosen:(`Default_to None)
    @@ List.map
         ~f:(Command.Param.map ~f:(Option.map ~f:Option.return))
         [from_file_flag; from_name_flag]
end

(** Protocol constants. Consensus constants are generated using these. *)
module Protocol = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('k, 'delta, 'genesis_state_timestamp) t =
          { k: 'k
          ; delta: 'delta
          ; genesis_state_timestamp: 'genesis_state_timestamp }
        [@@deriving eq, ord, hash, sexp, yojson]
      end
    end]

    type ('k, 'delta, 'genesis_state_timestamp) t =
          ('k, 'delta, 'genesis_state_timestamp) Stable.Latest.t =
      {k: 'k; delta: 'delta; genesis_state_timestamp: 'genesis_state_timestamp}
    [@@deriving eq, sexp, yojson]
  end

  [%%versioned_asserted
  module Stable = struct
    module V1 = struct
      type t = (int, int, Time.t) Poly.Stable.V1.t [@@deriving eq, ord, hash]

      let to_latest = Fn.id

      module Printing_proxy = struct
        type t = (int, int, string) Poly.t [@@deriving sexp, yojson]
      end

      let to_printing_proxy ({k; delta; genesis_state_timestamp} : t) :
          Printing_proxy.t =
        { k
        ; delta
        ; genesis_state_timestamp=
            Time.to_string_abs genesis_state_timestamp ~zone:Time.Zone.utc }

      let of_printing_proxy
          ({k; delta; genesis_state_timestamp} : Printing_proxy.t) =
        let open Result.Let_syntax in
        let%map genesis_state_timestamp =
          validate_time (Some genesis_state_timestamp)
        in
        ({k; delta; genesis_state_timestamp} : t)

      let to_yojson t = Printing_proxy.to_yojson (to_printing_proxy t)

      let of_yojson json =
        let open Result.Let_syntax in
        Printing_proxy.of_yojson json
        >>= of_printing_proxy
        |> Result.map_error
             ~f:(sprintf "Runtime_config.Protocol.of_yojson: %s")

      let sexp_of_t t = Printing_proxy.sexp_of_t (to_printing_proxy t)

      let t_of_sexp sexp =
        match of_printing_proxy (Printing_proxy.t_of_sexp sexp) with
        | Ok t ->
            t
        | Error e ->
            Error.raise
              (Error.createf "Runtime_config.Protocol.t_of_sexp: %s" e)
    end

    module Tests = struct
      let%test "protocol constants serialization v1" =
        let t : V1.t =
          { k= 1
          ; delta= 100
          ; genesis_state_timestamp=
              Time.of_string "2019-10-08 17:51:23.050849Z" }
        in
        (*from the print statement in Serialization.check_serialization*)
        let known_good_hash =
          "\x18\x3E\xF4\x11\xAC\x44\x83\xBF\x0E\x0F\x76\x5B\xF7\xE6\xFA\xE7\xEB\x24\xF6\xF7\xAA\xC8\x37\x71\xF7\xB9\x54\x66\xF6\x38\xB3\xF1"
        in
        Serialization.check_serialization (module V1) t known_good_hash
    end
  end]

  type t = Stable.Latest.t [@@deriving eq, yojson]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { protocol: Protocol.Stable.V1.t
      ; txpool_max_size: int
      ; accounts: Accounts.Stable.V1.t } [@@deriving yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t =
  {protocol: Protocol.t; txpool_max_size: int; accounts: Accounts.t} [@@deriving yojson]

let hash (t : t) =
  let str =
    ( List.map
        [t.protocol.k; t.protocol.delta; t.txpool_max_size]
        ~f:Int.to_string
    |> String.concat ~sep:"" )
    ^ Core.Time.to_string t.protocol.genesis_state_timestamp
  in
  Blake2.digest_string str |> Blake2.to_hex

[%%inject
"genesis_state_timestamp_string", genesis_state_timestamp]

[%%ifdef
consensus_mechanism]

[%%inject
"k", k]

[%%inject
"delta", delta]

[%%endif]

[%%inject
"pool_max_size", pool_max_size]

[%%inject
"genesis_ledger", genesis_ledger]

(* TODO: Hardcode the unit test values. *)

let for_unit_tests : t =
  { protocol=
      { k
      ; delta
      ; genesis_state_timestamp=
          genesis_timestamp_of_string genesis_state_timestamp_string }
  ; txpool_max_size= pool_max_size
  ; accounts= Named genesis_ledger }

(* TODO: Hoist this to later in the build.*)
let compile_config : t =
  { protocol=
      { k
      ; delta
      ; genesis_state_timestamp=
          genesis_timestamp_of_string genesis_state_timestamp_string }
  ; txpool_max_size= pool_max_size
  ; accounts= Named genesis_ledger }

module Config_file = struct
  type t =
    { k: int option
    ; delta: int option
    ; txpool_max_size: int option
    ; genesis_state_timestamp: string option
    ; accounts: Accounts.t option }
  [@@deriving yojson]

  let of_yojson s =
    Result.(
      of_yojson s
      >>= fun t -> validate_time t.genesis_state_timestamp >>= fun _ -> Ok t)

  let from_file filename =
    Yojson.Safe.from_file filename |> of_yojson |> Result.ok_or_failwith

  let to_file filename accounts =
    Yojson.Safe.to_file filename (to_yojson accounts)

  let from_flag =
    let open Command in
    let open Let_syntax in
    let%map_open filename =
      Param.flag "--config-file"
        ~doc:"filename The filename to load the runtime configuration from"
        (Flag.optional Param.string)
    in
    Option.map ~f:from_file filename
end

let of_config_file ~(default : t) (t : Config_file.t) : t =
  let opt default x = Option.value ~default x in
  let protocol =
    { Protocol.Poly.k= opt default.protocol.k t.k
    ; delta= opt default.protocol.delta t.delta
    ; genesis_state_timestamp=
        Option.value_map ~default:default.protocol.genesis_state_timestamp
          t.genesis_state_timestamp ~f:genesis_timestamp_of_string }
  in
  { protocol
  ; txpool_max_size= opt default.txpool_max_size t.txpool_max_size
  ; accounts= opt default.accounts t.accounts }

let to_config_file t : Config_file.t =
  { Config_file.k= Some t.protocol.k
  ; delta= Some t.protocol.delta
  ; txpool_max_size= Some t.txpool_max_size
  ; genesis_state_timestamp=
      Some
        (Core.Time.format t.protocol.genesis_state_timestamp
           "%Y-%m-%d %H:%M:%S%z" ~zone:Core.Time.Zone.utc)
  ; accounts= Some t.accounts }

let from_flags (default : t) =
  let open Command in
  let open Let_syntax in
  let%map_open config_file = Config_file.from_flag
  and txpool_max_size =
    Param.flag "--pool-size"
      ~doc:"max Set the maximum size of the transaction pool"
      (Flag.optional Param.int)
  and delta =
    Param.flag "--delta" ~doc:"delta Set the delta consensus parameter"
      (Flag.optional Param.int)
  and k =
    Param.flag "-k" ~doc:"k Set the k consensus parameter"
      (Flag.optional Param.int)
  and genesis_state_timestamp =
    Param.flag "--gensis-timestamp" ~doc:"timestamp Set the genesis timestamp"
      (Flag.optional Param.string)
  and accounts = Accounts.from_flags in
  (* Apply the config file first, so that flags take priority. *)
  let default =
    Option.value_map ~default ~f:(of_config_file ~default) config_file
  in
  (* Apply flags. *)
  let txpool_max_size =
    Option.value ~default:default.txpool_max_size txpool_max_size
  in
  let delta = Option.value ~default:default.protocol.delta delta in
  let k = Option.value ~default:default.protocol.k k in
  let accounts = Option.value ~default:default.accounts accounts in
  let genesis_state_timestamp =
    Option.value_map ~default:default.protocol.genesis_state_timestamp
      genesis_state_timestamp
      ~f:(fun genesis_state_timestamp ->
        match validate_time (Some genesis_state_timestamp) with
        | Ok ts ->
            ts
        | Error err ->
            failwith err )
  in
  {accounts; protocol= {delta; k; genesis_state_timestamp}; txpool_max_size}
