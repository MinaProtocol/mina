open Pipe_lib
open Core_kernel

val run :
     frontier:Transition_frontier.t
  -> on_block_body_update_ref:
       ([< `Added | `Broken ] -> Consensus.Body_reference.t list -> unit) ref
  -> context:(module Context.MINI_CONTEXT)
  -> trust_system:Trust_system.t
  -> verifier:Verifier.t
  -> network:Mina_networking.t
  -> time_controller:Block_time.Controller.t
  -> get_completed_work:
       (   Transaction_snark_work.Statement.t
        -> Transaction_snark_work.Checked.t option )
  -> collected_transitions:Transition_frontier.Gossip.element list
  -> network_transition_reader:
       Transition_frontier.Gossip.element Strict_pipe.Reader.t
  -> producer_transition_reader:Frontier_base.Breadcrumb.t Strict_pipe.Reader.t
  -> clear_reader:'a Strict_pipe.Reader.t
  -> verified_transition_writer:
       (Mina_block.Validated.t, 'c, unit) Strict_pipe.Writer.t
  -> unit
