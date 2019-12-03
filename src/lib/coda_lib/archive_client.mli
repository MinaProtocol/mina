open Pipe_lib

val run :
     logger:Logger.t
  -> archive_process_port:int
  -> frontier_broadcast_pipe:Transition_frontier.t option
                             Broadcast_pipe.Reader.t
  -> unit
