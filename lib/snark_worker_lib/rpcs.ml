open Core_kernel
open Async

module Make (Inputs : Intf.Inputs_intf) = struct
  open Inputs
  open Snark_work_lib

  module Get_work = struct
    type query = unit [@@deriving bin_io]

    type response =
      ( Statement.t
      , Super_transaction.t
      , Sparse_ledger.t
      , Proof.t )
      Work.Single.Spec.t
      Work.Spec.t
    [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Get_work" ~version:0 ~bin_query ~bin_response
  end

  module Submit_work = struct
    type msg =
      ( ( Statement.t
        , Super_transaction.t
        , Sparse_ledger.t
        , Proof.t )
        Work.Single.Spec.t
        Work.Spec.t
      , Proof.t )
      Work.Result.t
    [@@deriving bin_io]

    let rpc : msg Rpc.One_way.t =
      Rpc.One_way.create ~name:"Submit_work" ~version:0 ~bin_msg
  end
end
