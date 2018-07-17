open Core
open Async

module Get_work : sig
  type query = unit [@@deriving bin_io]

  type response = Work.Spec.t [@@deriving bin_io]

  val rpc : (query, response) Rpc.Rpc.t
end

module Submit_work : sig
  type msg = Work.Result.t [@@deriving bin_io]

  val rpc : msg Rpc.One_way.t
end
