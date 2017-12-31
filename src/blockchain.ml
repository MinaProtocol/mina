open Core_kernel
open Async_kernel

type t =
  { block : Block.t
  ; proof : Proof.t
  }
[@@deriving bin_io]

type blockchain = t

module Update = struct
  type t =
    | New_block of blockchain
end

let valid t = failwith "TODO"

let accumulate ~init ~updates ~strongest_block =
  don't_wait_for begin
    let%map _last_block =
      Pipe.fold updates ~init ~f:(fun block (Update.New_block new_block) ->
        match (block, valid new_block) with
        | (_, false) -> return block
        | (None, true) -> return (Some new_block)
        | (Some block, true) -> 
          match Block.strongest block.block new_block.block with
          | `First ->
            return (Some block)
          | `Second ->
            let%map () = Pipe.write strongest_block new_block in
            Some new_block)
    in
    ()
  end

let genesis = { block = Block.genesis; proof = Libsnark_todo }
