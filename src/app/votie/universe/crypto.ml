open Core_kernel
module Backend = Snarky.Backends.Bn128.Default
module Impl = Snarky.Snark.Make (Backend)
module Run = Snarky.Snark.Run.Make (Backend) (Unit)
module Field = Impl.Field
