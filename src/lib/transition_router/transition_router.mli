open Coda_base
open Coda_transition
open Pipe_lib

val run :
     logger:Logger.t
  -> trust_system:Trust_system.t
  -> transition_reader:( [ `Transition of
                           External_transition.t Envelope.Incoming.t ]
                       * [`Time_received of Block_time.t] )
                       Strict_pipe.Reader.t
  -> valid_transition_writer:( [ `Transition of
                                 ( [`Time_received] * Truth.true_t
                                 , [`Proof] * Truth.true_t
                                 , [`Frontier_dependencies] * Truth.false_t
                                 , [`Staged_ledger_diff] * Truth.false_t )
                                 External_transition.Validation.with_transition
                                 Envelope.Incoming.t ]
                               * [`Time_received of Block_time.t]
                             , Strict_pipe.crash Strict_pipe.buffered
                             , unit )
                             Strict_pipe.Writer.t
  -> unit
