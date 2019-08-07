module type S_unchecked = Intf.S_unchecked

module type S_checked = Intf.S_checked

module type S = Intf.S

module Make : Intf.F

module Make32 () : Intf.UInt32

module Make64 () : Intf.UInt64
