let () = Zexe_backend.Dlog_based.Keypair.set_urs_info Cache_dir.cache

let () = Zexe_backend.Pairing_based.Keypair.set_urs_info Cache_dir.cache

module Tock = struct
  module Full = Pickles.Impls.Dlog_based
  module Run = Pickles.Impls.Dlog_based

  let group_map_params () = Lazy.force Group_map_params.params

  include Full.Internal_Basic
  module Number = Snarky.Number.Make (Full.Internal_Basic)
  module Enumerable = Snarky.Enumerable.Make (Full.Internal_Basic)
  module Inner_curve = Zexe_backend.G1
end

module Tick = struct
  module Full = Pickles.Impls.Pairing_based
  module Run = Pickles.Impls.Pairing_based

  let group_map_params =
    Group_map.Params.create
      (module Zexe_backend.Fq)
      Zexe_backend.G1.Params.{a; b}

  include Full.Internal_Basic
  module Number = Snarky.Number.Make (Full.Internal_Basic)
  module Enumerable = Snarky.Enumerable.Make (Full.Internal_Basic)
  module Inner_curve = Zexe_backend.G
end
