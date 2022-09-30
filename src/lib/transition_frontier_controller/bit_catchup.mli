open Pipe_lib

val run :
     context:(module Transition_handler.Validator.CONTEXT)
  -> trust_system:Trust_system.t
  -> verifier:Verifier.t
  -> network:Mina_networking.t
  -> time_controller:Block_time.Controller.t
  -> collected_transitions:Bootstrap_controller.Transition_cache.element list
  -> frontier:Transition_frontier.t
  -> network_transition_reader:Types.produced_transition Strict_pipe.Reader.t
  -> producer_transition_reader:Frontier_base.Breadcrumb.t Strict_pipe.Reader.t
  -> clear_reader:'a Strict_pipe.Reader.t
  -> verified_transition_writer:
       ( [> `Transition of Mina_block.Validated.t ]
         * [> `Source of [ `Catchup | `Gossip | `Internal ] ]
         * [> `Valid_cb of 'b option ]
       , 'c
       , unit )
       Strict_pipe.Writer.t
  -> unit Async.Deferred.t
