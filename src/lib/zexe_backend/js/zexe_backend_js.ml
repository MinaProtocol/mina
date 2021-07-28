open Zexe_backend
open Core_kernel

module Inputs_common = struct
  module Store = Key_cache_js.Trivial

  let run_in_thread f =
    (* TODO: Somehow actually run this asynchronously *)
    Async_kernel.return (f ())

  let store ~read ~write =
    Store.Disk_storable.simple
      (fun name -> name)
      (fun _name ~path ->
        Or_error.try_with_join (fun () ->
            match read path with
            | Some urs ->
                Ok urs
            | None ->
                Or_error.errorf
                  "Could not read the URS from disk; its format did not match \
                   the expected format"))
      (fun _ urs path ->
        Or_error.try_with (fun () ->
            write urs path))
end

module Pasta = struct
  open Pasta

  module Vesta_based_plonk = Vesta_based_plonk.Make (struct
    include Inputs_common

    let store =
      store ~read:Marlin_plonk_bindings.Pasta_fp_urs.read
        ~write:Marlin_plonk_bindings.Pasta_fp_urs.write
  end)

  module Pallas_based_plonk = Pallas_based_plonk.Make (struct
    include Inputs_common

    let store =
      store ~read:Marlin_plonk_bindings.Pasta_fq_urs.read
        ~write:Marlin_plonk_bindings.Pasta_fq_urs.write
  end)
end
