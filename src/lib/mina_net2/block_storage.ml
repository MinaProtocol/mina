open Core_kernel
open Lmdb

type t =
  { (* statuses is a map from 32-byte key to a 1-byte value representing the status of a root bitswap block *)
    statuses : (Consensus.Body_reference.t, int, [ `Uni ]) Map.t
  ; blocks : (Blake2.t, Bigstring.t, [ `Uni ]) Map.t
  ; logger : Logger.t
  ; env : Env.t
  }

module Root_block_status = struct
  type t = Partial | Full | Deleting [@@deriving enum]
end

let body_tag = Staged_ledger_diff.Body.Tag.(to_enum Body)

let full_status = Root_block_status.to_enum Full

let uint8_conv =
  Conv.make
    ~flags:Conv.Flags.(integer_key + integer_dup + dup_fixed)
    ~serialise:(fun alloc x ->
      let a = alloc 1 in
      Bigstring.set_uint8_exn a ~pos:0 x ;
      a )
    ~deserialise:(Bigstring.get_uint8 ~pos:0)
    ()

let blake2_conv =
  Conv.make
    ~serialise:(fun alloc x ->
      let str = Blake2.to_raw_string x in
      Conv.serialise Conv.string alloc str )
    ~deserialise:(fun s ->
      Conv.deserialise Conv.string s |> Blake2.of_raw_string )
    ()

let open_ ~logger dir =
  let env = Env.create ~max_maps:1 Ro dir in
  (* Env. *)
  let blocks =
    Map.open_existing ~key:blake2_conv ~value:Conv.bigstring Nodup env
  in
  let statuses =
    Map.open_existing ~key:blake2_conv ~value:uint8_conv ~name:"status" Nodup
      env
  in
  { blocks; statuses; logger; env }

let get_status { statuses; logger; _ } body_ref =
  try
    let raw_status = Map.get statuses body_ref in
    match Root_block_status.of_enum raw_status with
    | None ->
        [%log error] "Unexpected status $status for $body_reference"
          ~metadata:
            [ ("status", `Int raw_status)
            ; ("body_reference", Consensus.Body_reference.to_yojson body_ref)
            ] ;
        None
    | Some x ->
        Some x
  with Not_found -> None

let read_block blocks logger txn key =
  let%bind.Option raw =
    try Map.get ~txn blocks key |> Some with Not_found -> None
  in
  match Staged_ledger_diff.Bitswap_block.parse_block raw with
  | Ok a ->
      Some a
  | Error e ->
      [%log error] "Error parsing bitswap block $key: $error"
        ~metadata:
          [ ("key", Blake2.to_yojson key)
          ; ("error", `String (Error.to_string_hum e))
          ] ;
      None

let read_body_impl blocks logger txn body_ref =
  let%bind.Option root_links, root_data =
    read_block blocks logger txn body_ref
  in
  let%bind.Option () =
    if Bigstring.length root_data < 5 then (
      [%log error]
        "Couldn't read root block for $body_reference: data section is too \
         short"
        ~metadata:
          [ ("body_reference", Consensus.Body_reference.to_yojson body_ref) ] ;
      None )
    else Some ()
  in
  let len = Bigstring.get_uint32_le root_data ~pos:0 - 1 in
  let%bind.Option () =
    let raw_tag = Bigstring.get_uint8 root_data ~pos:4 in
    if body_tag = raw_tag then Some ()
    else (
      [%log error] "Unexpected tag $tag for $body_reference"
        ~metadata:
          [ ("body_reference", Consensus.Body_reference.to_yojson body_ref)
          ; ("tag", `Int raw_tag)
          ] ;
      None )
  in
  let buf = Bigstring.create len in
  let pos = ref (Bigstring.length root_data - 5) in
  Bigstring.blit ~src:root_data ~src_pos:5 ~dst:buf ~dst_pos:0 ~len:!pos ;
  let q = Queue.create () in
  Queue.enqueue_all q root_links ;
  let exited_early = ref false in
  while not (Queue.is_empty q) do
    match read_block blocks logger txn (Queue.dequeue_exn q) with
    | None ->
        Queue.clear q ;
        exited_early := true
    | Some (links, data) ->
        Bigstring.blit ~src:data ~src_pos:0 ~dst:buf ~dst_pos:!pos
          ~len:(Bigstring.length data) ;
        pos := !pos + Bigstring.length data ;
        Queue.enqueue_all q links
  done ;
  let%bind.Option () = if !exited_early then None else Some () in
  let res =
    Staged_ledger_diff.Body.Stable.bin_read_to_latest_opt buf ~pos_ref:(ref 0)
  in
  if Option.is_none res then
    [%log error] "Failed to deserialize body for $body_reference"
      ~metadata:
        [ ("body_reference", Consensus.Body_reference.to_yojson body_ref) ] ;
  res

let read_body { statuses; logger; blocks; env } body_ref =
  let impl txn =
    try
      if Map.get ~txn statuses body_ref = full_status then (
        let res = read_body_impl blocks logger txn body_ref in
        if Option.is_none res then
          [%log error] "Couldn't read body for $body_reference with Full status"
            ~metadata:
              [ ("body_reference", Consensus.Body_reference.to_yojson body_ref)
              ] ;
        res )
      else None
    with Not_found -> None
  in
  match Txn.go Ro env impl with
  | None ->
      [%log error]
        "LMDB transaction failed unexpectedly while reading block \
         $body_reference"
        ~metadata:
          [ ("body_reference", Consensus.Body_reference.to_yojson body_ref) ] ;
      None
  | Some x ->
      x
