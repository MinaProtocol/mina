module Update : sig
  type t =
    | New_chain of Blockchain.t
end

val accumulate
  :  init:Blockchain.t
  -> prover:Prover.t
  -> updates:Update.t Linear_pipe.Reader.t
  -> strongest_chain:Blockchain.t Linear_pipe.Writer.t
  -> unit
