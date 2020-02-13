module type Buffer_rules_intf = sig end

module type Intf = sig end

module Make (Rules : Buffer_rules_intf) : Intf = struct end
