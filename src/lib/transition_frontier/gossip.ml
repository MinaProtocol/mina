open Core_kernel

type initial_valid_block_or_header =
  [ `Block of Mina_block.initial_valid_block
  | `Header of Mina_block.initial_valid_header ]

type gossip_data =
  { valid_cb : Mina_net2.Validation_callback.t option
  ; type_ : [ `Block | `Header ]
  ; sender : Network_peer.Envelope.Sender.t
  ; received_at : Time.t
  }

(** Map from topic to validation callback  *)
type gossip_map = gossip_data String.Map.t

type element = initial_valid_block_or_header * [ `Gossip_map of gossip_map ]

let header_with_hash e =
  match e with
  | `Block b ->
      With_hash.map ~f:Mina_block.header
      @@ Mina_block.Validation.block_with_hash b
  | `Header h ->
      Mina_block.Validation.header_with_hash h

let fire_ignore_to_validation_callbacks =
  String.Map.iter ~f:(function
    | { valid_cb = Some valid_cb; _ } ->
        Mina_net2.Validation_callback.fire_if_not_already_fired valid_cb `Ignore
    | _ ->
        () )

let senders gd_map =
  String.Map.data gd_map |> List.map ~f:(fun { sender; _ } -> sender)

let valid_cbs gd_map =
  String.Map.data gd_map |> List.filter_map ~f:(fun { valid_cb; _ } -> valid_cb)

let has_valid_cb gd_map =
  String.Map.data gd_map
  |> List.find ~f:(function { valid_cb = Some _; _ } -> true | _ -> false)
  |> Option.is_some

let gossip_data_of_transition_envelope ?valid_cb ?(type_ = `Block)
    transition_env =
  { received_at = transition_env.Network_peer.Envelope.Incoming.received_at
  ; sender = transition_env.Network_peer.Envelope.Incoming.sender
  ; type_
  ; valid_cb
  }
