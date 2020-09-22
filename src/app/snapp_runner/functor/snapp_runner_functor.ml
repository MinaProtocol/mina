module Intf = struct
  module type Input = sig end

  module type S = sig end

  module type Commands = sig end

  module type S_with_commands = sig
    include S

    include Commands
  end
end

module Make (X : Intf.Input) : Intf.S = struct end

module Make_commands (X : Intf.S) : Intf.Commands = struct end

module Make_with_commands (X : Intf.Input) : Intf.S_with_commands = struct
  module T = Make (X)
  module Commands = Make_commands (X)
  include T
  include Commands
end
