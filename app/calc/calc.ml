open Core_kernel
open Async_kernel
open Snarky
open Impl
open Let_syntax

module Command = struct
  type t =
    | Nop
    | Push of int
    | Add
  let foo = Field.d
end

