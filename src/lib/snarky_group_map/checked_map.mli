module Make
    (M : Snarky.Snark_intf.Run) (Params : sig
        val a : M.Field.t

        val b : M.Field.t
    end) : sig
  val to_group : M.Field.t -> M.Field.t * M.Field.t
end
