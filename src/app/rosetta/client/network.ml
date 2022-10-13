open Core

module Block_id = struct
  type t = {
      index : Mina_numbers.Global_slot.t;
      hash : Mina_base.State_hash.t;
    } [@@deriving make, yojson]

  let of_json json =
    let open Json.Validation.Let_syntax in
    let%map index =
      Json.get "index" json >>= Json.Expect.int >>| Mina_numbers.Global_slot.of_int
    and hash =
      let%bind raw = Json.get "hash" json >>= Json.Expect.string in
      Mina_base.State_hash.of_base58_check raw
      |> Result.map_error ~f:(fun e -> [Json.Error.wrap_core_error json e])
    and () =
      Json.assert_no_excess_keys ~keys:["hash"; "index"] json
    in
    { index; hash }
end

module Sync = struct
  type t = {
      current_index : Mina_numbers.Global_slot.t;
      stage : Sync_status.t;
    } [@@deriving make]

  let of_json json =
    let open Json.Validation.Let_syntax in
    let%map current_index =
      Json.get "current_index" json >>= Json.Expect.int >>| Mina_numbers.Global_slot.of_int
    and stage =
      let%bind raw = Json.get "stage" json >>= Json.Expect.string in
      Sync_status.of_string raw
      |> Result.map_error ~f:(fun e -> [Json.Error.wrap_core_error json e])
    and () =
      Json.assert_no_excess_keys ~keys:["current_index"; "stage"] json
    in
    { current_index; stage }

  let of_yojson (j : Yojson.Safe.t) : (t, string) Ppx_deriving_yojson_runtime.Result.result =
    match of_json (j :> Yojson.t) with
    | Ok t -> Ok t
    | Error es -> Error (List.map ~f:Json.Error.to_string es |> String.concat ~sep:"\n")

  let to_yojson {current_index; stage} : Yojson.Safe.t =
    `Assoc [("current_index", `Int (Mina_numbers.Global_slot.to_int current_index));
            ("stage", Sync_status.to_yojson stage)]
end

module Peer = struct
  type t = { peer_id : Network_peer.Peer.Id.t }
             [@@deriving make, yojson]

  let of_json json =
    let open Json.Validation.Let_syntax in
    let%bind raw = Json.get "peer_id" json >>= Json.Expect.string in
    let%map peer_id =
      try return @@ Network_peer.Peer.Id.unsafe_of_string raw with
      | e -> Json.Validation.fail @@ Json.Error.wrap_exn json e
    and () =
      Json.assert_no_excess_keys ~keys:["peer_id"] json
    in
    { peer_id }
end

module Status = struct
  type t = {
      current_block_identifier : Block_id.t;
      genesis_block_identifier : Block_id.t;
      current_block_timestamp : int64;
      sync_status : Sync.t;
      peers : Peer.t list;
    } [@@deriving make, yojson]

  let uri = "/network/status"
  let query =
    `Assoc [ ("network_identifier", `Assoc [ ("blockchain", `String "mina")
                                           ; ("network", `String "debug") ]) ]

  let of_json json =
    let open Json.Validation.Let_syntax in
    Result.map_error ~f:Json.Error.to_exn @@
    let%map current_block_identifier =
      Json.get "current_block_identifier" json >>= Block_id.of_json
    and current_block_timestamp =
      Json.get "current_block_timestamp" json >>= Json.Expect.int64
    and genesis_block_identifier =
      Json.get "genesis_block_identifier" json >>= Block_id.of_json
    and sync_status =
      Json.get "sync_status" json >>= Sync.of_json
    and peers =
      Json.get "peers" json >>= Json.Expect.list >>= Json.Validation.map_m ~f:Peer.of_json
    and () = Json.assert_no_excess_keys
               ~keys:[ "current_block_identifier"
                     ; "current_block_timestamp"
                     ; "genesis_block_identifier"
                     ; "sync_status"
                     ; "peers" ]
               json
    in
    { current_block_identifier
    ; current_block_timestamp
    ; genesis_block_identifier
    ; sync_status
    ; peers }

  let to_string t = Yojson.Safe.pretty_to_string (to_yojson t)
end

module Version = struct
  type t = {
      rosetta_version : int * int * int;
      node_version : int * int * int;
      middleware_version : (int * int * int) option;
      (* There's also an optional metadata field, which can contain an arbitrary
         JSON. As such it would be troublesome to gather here (can't convert
         Yojson.t to Yojson.Safe.t) and we don't return it anyway. *)
    } [@@deriving make, yojson]

  exception Invalid_version of string

  let v_of_json json =
    let open Json.Validation.Let_syntax in
    let%bind v = Json.Expect.string json in
    match String.split ~on:'.' v with
    | [major; minor; patch] ->
       (try return (Int.of_string major, Int.of_string minor, Int.of_string patch) with
        | e -> Json.Validation.fail @@ Json.Error.wrap_exn json e)
    | _ ->
       Json.Validation.fail (Json.Error.wrap_exn json @@ Invalid_version v)

  let of_json json =
    let open Json.Validation in
    let open Json.Validation.Let_syntax in
    let%map () =
      Json.assert_no_excess_keys
        ~keys:[ "rosetta_version"
              ; "node_version"
              ; "middleware_version"
              ; "metadata" ]
        json
    and rosetta_version =
      Json.get "rosetta_version" json >>= v_of_json
    and node_version =
      Json.get "node_version" json >>= v_of_json
    and middleware_version =
      Json.get_opt "middleware_version" json >>=? v_of_json
    in
    { rosetta_version
    ; node_version
    ; middleware_version }   
end

module Operation_status = struct
  type t = {
      status : string;
      successful : bool;
    } [@@deriving make, yojson]

  let of_json json =
    let open Json.Validation.Let_syntax in
    let%map status = Json.get "status" json >>= Json.Expect.string
    and successful = Json.get "successful" json >>=Json.Expect.bool in
    { status; successful }
end

module Network_error = struct
  type t = {
      code : Json.UInt.t;
      message : string;
      description : string option;
      retriable : bool;
      (* Details field omitted as it's optional and
         contains arbitrary JSON. *)
    } [@@deriving make, yojson]

  let of_json json =
    let open Json.Validation in
    let open Let_syntax in
    let%map code =
      Json.get "code" json >>= Json.Expect.int64 >>| Unsigned.UInt.of_int64
    and message = Json.get "message" json >>= Json.Expect.string
    and description = Json.get_opt "description" json >>=? Json.Expect.string
    and retriable = Json.get "retriable" json >>= Json.Expect.bool in
    { code; message; description; retriable }
end

module Currency = struct
  type t = {
      symbol : string;
      decimals : int;
      (* Metadata field omitted, as it's optional
         and contains arbitrary JSON. *)
    } [@@deriving make, yojson]

  let of_json json =
    let open Json.Validation.Let_syntax in
    let%map symbol = Json.get "symbol" json >>= Json.Expect.string
    and decimals = Json.get "decimals" json >>= Json.Expect.int in
    { symbol; decimals }
end

module Exemption_type = struct
  type t = GTE | LTE | Dynamic
    [@@deriving yojson]

  let of_json =
    Json.Expect.enum
      ~variants:[ ("greater_or_equal", GTE)
                ; ("less_or_equal", LTE)
                ; ("dynamic", Dynamic)]
end

module Balance_exemption = struct
  type t = {
      sub_account_address : string option;
      currency : Currency.t option;
      exemption_type : Exemption_type.t option;
    } [@@deriving make, yojson]

  let of_json json =
    let open Json.Validation in
    let open Let_syntax in
    let%map sub_account_address =
      Json.get_opt "sub_account_address" json >>=? Json.Expect.string
    and currency =
      Json.get_opt "currency" json >>=? Currency.of_json
    and exemption_type =
      Json.get_opt "exemption_type" json >>=? Exemption_type.of_json in
    { sub_account_address; currency; exemption_type }
end

module Case = struct
  type t = Upper_case
         | Lower_case
         | Case_sensitive
         | Insensitive
    [@@deriving yojson]

  let of_json =
    Json.Expect.enum
      ~variants:[ ("upper_case", Upper_case)
                ; ("lower_case", Lower_case)
                ; ("case_sensitive", Case_sensitive)
                ; ("null", Insensitive) ]
end

module Allow = struct
  type t = {
      operation_statuses : Operation_status.t list;
      operation_types : string list;
      errors : Network_error.t list;
      historical_balance_lookup : bool;
      timestamp_start_index : Json.UInt64.t option;
      call_methods : string list;
      balance_exemptions : Balance_exemption.t list;
      mempool_coins : bool;
      block_hash_case : Case.t option;
      transaction_hash_case : Case.t option;
    } [@@deriving make, yojson]

  let of_json json =
    let open Json.Validation in
    let open Let_syntax in
    let%map operation_statuses =
      Json.get "operation_statuses" json >>= Json.Expect.list
      >>= map_m ~f:Operation_status.of_json
    and operation_types =
      Json.get "operation_types" json >>= Json.Expect.list
      >>= map_m ~f:Json.Expect.string
    and errors =
      Json.get "errors" json >>= Json.Expect.list
      >>= map_m ~f:Network_error.of_json
    and historical_balance_lookup =
      Json.get "historical_balance_lookup" json >>= Json.Expect.bool
    and timestamp_start_index =
      Json.get_opt "timestamp_start_index" json >>=? (fun tsi ->
        Json.Expect.int64 tsi >>| Unsigned.UInt64.of_int64)
    and call_methods =
      Json.get "call_methods" json >>= Json.Expect.list
      >>= map_m ~f:Json.Expect.string
    and balance_exemptions =
      Json.get "balance_exemptions" json >>= Json.Expect.list
      >>= map_m ~f:Balance_exemption.of_json
    and mempool_coins =
      Json.get "mempool_coins" json >>= Json.Expect.bool
    and block_hash_case =
      Json.get_opt "block_hash_case" json >>=? Case.of_json
    and transaction_hash_case =
      Json.get_opt "transaction_hash_case" json >>=? Case.of_json in
    { operation_statuses
    ; operation_types
    ; errors
    ; historical_balance_lookup
    ; timestamp_start_index
    ; call_methods
    ; balance_exemptions
    ; mempool_coins
    ; block_hash_case
    ; transaction_hash_case }
end

module Options = struct
  type t = {
      version : Version.t;
      allow : Allow.t;
    } [@@deriving make, yojson]

  let uri = "/network/options"
  
  let query =
    `Assoc [ ("network_identifier", `Assoc [ ("blockchain", `String "mina")
                                           ; ("network", `String "debug") ]) ]

  let of_json json =
    let open Json.Validation.Let_syntax in
    Result.map_error ~f:Json.Error.to_exn @@
      let%map version = Json.get "version" json >>= Version.of_json
      and allow = Json.get "allow" json >>= Allow.of_json in
      { version; allow }
  
  let to_string t = Yojson.Safe.pretty_to_string (to_yojson t)
end
