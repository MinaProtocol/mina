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
    let rec go block =
      let%bind update = Pipe.read updates in
      match update with
      | `Eof -> return ()
      | `Ok (Update.New_block new_block) ->
        match Block.strongest block new_block with
        | `First ->
          go block
        | `Second ->
          let%bind () = Pipe.write strongest_block new_block in
          go new_block
    in
    go init
  end
