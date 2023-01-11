open Pipe_lib

val create_in_mem_transition_states :
     trust_system:Trust_system.t
  -> logger:Logger.t
  -> Bit_catchup_state.Transition_states.t

val run :
     frontier:Transition_frontier.t
  -> on_bitswap_update_ref:Mina_net2.on_bitswap_update_t Core_kernel.ref
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
