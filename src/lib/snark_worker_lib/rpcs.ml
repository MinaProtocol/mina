open Core_kernel
open Async

module Make (Inputs : Intf.Inputs_intf) = struct
  open Inputs
  open Snark_work_lib

  module Get_work = struct
    type query = unit [@@deriving bin_io]

    type response =
      ( Statement.Stable.V1.t
      , Transaction.t
      , Transaction_witness.t
      , Proof.t )
      Work.Single.Spec.t
      Work.Spec.t
      option
    [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Get_work" ~version:0 ~bin_query ~bin_response
  end

  module Submit_work = struct
    type query =
      ( ( Statement.Stable.V1.t
        , Transaction.t
        , Transaction_witness.t
        , Proof.t )
        Work.Single.Spec.t
        Work.Spec.t
      , Proof.t )
      Work.Result.t
    [@@deriving bin_io]

    type response = unit [@@deriving bin_io, sexp]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Submit_work" ~version:0 ~bin_query ~bin_response
  end
end
