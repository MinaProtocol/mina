module Make
    (M : Snarky.Snark_intf.Run) (Params : sig
        val params : M.field Group_map.Params.t
    end) : sig
  val to_group : M.Field.t -> M.Field.t * M.Field.t
end
