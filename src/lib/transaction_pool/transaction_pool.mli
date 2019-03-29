open Pipe_lib

type t

val create :
     logger:Logger.t
  -> frontier_broadcast_pipe:Transition_frontier.t option Broadcast_pipe.Reader.t
  -> t
