(* for versioning of the types here, see

   RFC 0012, and

   https://ocaml.janestreet.com/ocaml-core/latest/doc/async_rpc_kernel/Async_rpc_kernel/Versioned_rpc/
*)

(* for each RPC, return the Master module only, and not the versioned modules,
   because the functor should not return types with bin_io; the versioned
   modules are defined in snark_worker.ml
*)

module Make = struct
  module Get_work = Rpc_get_work.Master
  module Submit_work = Rpc_submit_work.Master
  module Failed_to_generate_snark = Rpc_failed_to_generate_snark.Master
end
