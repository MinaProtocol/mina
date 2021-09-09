[%%import "/src/config.mlh"]

module Intf = Intf

module Make : Intf.F

[%%ifdef consensus_mechanism]

module Make_checked : Intf.F_checked

[%%endif]

module Make32 () : Intf.UInt32

module Make64 () : Intf.UInt64
