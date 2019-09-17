module type S = Intf.S

module Make : Intf.F

module Make32 () : Intf.UInt32

module Make64 () : Intf.UInt64
