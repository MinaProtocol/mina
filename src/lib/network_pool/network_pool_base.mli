module Make : functor
  (Transition_frontier : sig
     type t
   end)
  (Resource_pool : sig
     type t

     val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

     val label : string

     type transition_frontier_diff

     module Config : sig
       type t

       val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
     end

     val handle_transition_frontier_diff :
       transition_frontier_diff -> t -> unit Async_kernel.Deferred.t

     val create :
          constraint_constants:Genesis_constants.Constraint_constants.t
       -> consensus_constants:Consensus.Constants.t
       -> time_controller:Block_time.Controller.t
       -> frontier_broadcast_pipe:
            Transition_frontier.t Core_kernel.Option.t
            Pipe_lib.Broadcast_pipe.Reader.t
       -> config:Config.t
       -> logger:Logger.t
       -> tf_diff_writer:
            ( transition_frontier_diff
            , Pipe_lib.Strict_pipe.synchronous
            , unit Async_kernel.Deferred.t )
            Pipe_lib.Strict_pipe.Writer.t
       -> t

     module Diff : sig
       type t_ := t

       type t

       val to_yojson : t -> Yojson.Safe.t

       val t_of_sexp : Sexplib0.Sexp.t -> t

       val sexp_of_t : t -> Sexplib0.Sexp.t

       type verified

       val verified_to_yojson : verified -> Yojson.Safe.t

       val sexp_of_verified : verified -> Ppx_sexp_conv_lib.Sexp.t

       val verified_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> verified

       type rejected

       val rejected_to_yojson : rejected -> Yojson.Safe.t

       val sexp_of_rejected : rejected -> Ppx_sexp_conv_lib.Sexp.t

       val rejected_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> rejected

       val empty : t

       val reject_overloaded_diff : verified -> rejected

       val size : t -> int

       val verified_size : verified -> int

       val score : t -> int

       val max_per_15_seconds : int

       val summary : t -> string

       val verify :
            t_
         -> t Network_peer.Envelope.Incoming.t
         -> verified Network_peer.Envelope.Incoming.t
            Async_kernel.Deferred.Or_error.t

       val unsafe_apply :
            t_
         -> verified Network_peer.Envelope.Incoming.t
         -> ( t * rejected
            , [ `Locally_generated of t * rejected
              | `Other of Core_kernel.Error.t ] )
            Core_kernel.Result.t
            Async_kernel.Deferred.t

       val is_empty : t -> bool
     end

     val get_rebroadcastable :
          t
       -> has_timed_out:(Core_kernel.Time.t -> [ `Ok | `Timed_out ])
       -> Diff.t list
   end)
  -> sig
  type t

  module Broadcast_callback : sig
    type t =
      | Local of
          (   (Resource_pool.Diff.t * Resource_pool.Diff.rejected)
              Core_kernel.Or_error.t
           -> unit)
      | External of Mina_net2.Validation_callback.t
  end

  val create :
       config:Resource_pool.Config.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> consensus_constants:Consensus.Constants.t
    -> time_controller:Block_time.Controller.t
    -> incoming_diffs:
         ( Resource_pool.Diff.t Network_peer.Envelope.Incoming.t
         * Mina_net2.Validation_callback.t )
         Pipe_lib.Strict_pipe.Reader.t
    -> local_diffs:
         ( Resource_pool.Diff.t
         * (   (Resource_pool.Diff.t * Resource_pool.Diff.rejected)
               Core_kernel.Or_error.t
            -> unit) )
         Pipe_lib.Strict_pipe.Reader.t
    -> frontier_broadcast_pipe:
         Transition_frontier.t Core_kernel.Option.t
         Pipe_lib.Broadcast_pipe.Reader.t
    -> logger:Logger.t
    -> t

  val of_resource_pool_and_diffs :
       Resource_pool.t
    -> logger:Logger.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> incoming_diffs:
         ( Resource_pool.Diff.t Network_peer.Envelope.Incoming.t
         * Mina_net2.Validation_callback.t )
         Pipe_lib.Strict_pipe.Reader.t
    -> local_diffs:
         ( Resource_pool.Diff.t
         * (   (Resource_pool.Diff.t * Resource_pool.Diff.rejected)
               Core_kernel.Or_error.t
            -> unit) )
         Pipe_lib.Strict_pipe.Reader.t
    -> tf_diffs:
         Resource_pool.transition_frontier_diff Pipe_lib.Strict_pipe.Reader.t
    -> t

  val resource_pool : t -> Resource_pool.t

  val broadcasts : t -> Resource_pool.Diff.t Pipe_lib.Linear_pipe.Reader.t

  val create_rate_limiter : unit -> Rate_limiter.t

  val apply_and_broadcast :
       t
    -> Resource_pool.Diff.verified Network_peer.Envelope.Incoming.t
    -> Broadcast_callback.t
    -> unit Async_kernel.Deferred.t
end
