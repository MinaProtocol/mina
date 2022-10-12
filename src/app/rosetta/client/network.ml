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
    `Assoc [
        ("network_identifier", `Assoc [
                                   ("blockchain", `String "mina");
                                   ("network", `String "debug");
        ])
      ]

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
  
