
module Gen (S : sig val sctx : Super_context.t end) = struct

  let setup_library_odoc_rules _ ~scope:_ ~modules:_ ~requires:_
        ~dep_graphs:_ = ()

  let init () = ()

  let gen_rules ~dir:_ _ = ()
end
