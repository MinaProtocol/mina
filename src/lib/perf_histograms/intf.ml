open Async

type ('q, 'r) dispatch =
  Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t

type ('q, 'r, 'state) impl = 'state -> version:int -> 'q -> 'r Deferred.t

module Rpc = struct
  module type S = sig
    module Caller : sig
      type query

      type response
    end

    module Callee : sig
      type query

      type response
    end

    include
      Versioned_rpc.Both_convert.Plain.S
      with type callee_query := Callee.query
       and type callee_response := Callee.response
       and type caller_query := Caller.query
       and type caller_response := Caller.response
  end
end

module Patched = struct
  module type S = sig
    type callee_query

    type callee_response

    type caller_query

    type caller_response

    val dispatch_multi : (caller_query, caller_response) dispatch

    val implement_multi :
         ?log_not_previously_seen_version:(name:string -> int -> unit)
      -> (callee_query, callee_response, 'state) impl
      -> 'state Async.Rpc.Implementation.t list
  end
end
