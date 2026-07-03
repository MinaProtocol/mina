include
  Branch_data_intf.S
    with type Domain_log2.Stable.V1.t =
      Mina_wire_types.Pickles_composition_types.Branch_data.Domain_log2.V1.t
     and type Stable.V1.t =
      Mina_wire_types.Pickles_composition_types.Branch_data.V1.t
     and type Stable.V2.t =
      Mina_wire_types.Pickles_composition_types.Branch_data.V2.t
     and type t = Mina_wire_types.Pickles_composition_types.Branch_data.V2.t

(** [to_stable_v1 t] downgrades the in-memory branch data to its [V1] wire
    encoding. Raises if more than 2 proofs are verified. *)
val to_stable_v1 : t -> Stable.V1.t

(** [of_stable_v1 t] upgrades the [V1] wire encoding to the in-memory branch
    data. *)
val of_stable_v1 : Stable.V1.t -> t
