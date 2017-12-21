open Core_kernel
open Async_kernel

module Update = struct
  type t =
    | New_block of Block.t
end

type t =
  { block : Block.t
  ; proof : Proof.t
  }
[@@deriving bin_io]

let accumulate ~init ~updates ~strongest_block =
  don't_wait_for begin
    let%map _last_block =
      Pipe.fold updates ~init ~f:(fun block (Update.New_block new_block) ->
        match Block.strongest block new_block with
        | `First ->
          return block
        | `Second ->
          let%map () = Pipe.write strongest_block new_block in
          new_block)
    in
    ()
  end
