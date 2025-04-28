open Pipe_lib.Broadcast_pipe

let reader, writer = create 0

let update f = Writer.write writer (f (Reader.peek reader))

let incr () = update (( + ) 1)

let decr () = update (( - ) 1)
