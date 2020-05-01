include Intf
module Any = Any
module Libp2p = Libp2p
module Fake = Fake

module type S = sig
  module Rpc_intf : Coda_base.Rpc_intf.Rpc_interface_intf

  include module type of Intf

  module Consensus_message : module type of Consensus_message

  module Any : Any.S with module Rpc_intf := Rpc_intf

  module Libp2p : Libp2p.S with module Rpc_intf := Rpc_intf

  module Fake : Fake.S with module Rpc_intf := Rpc_intf
end

module Make (Rpc_intf : Coda_base.Rpc_intf.Rpc_interface_intf) :
  S with module Rpc_intf := Rpc_intf = struct
  include Intf
  module Consensus_message = Consensus_message
  module Any = Any.Make (Rpc_intf)
  module Fake = Fake.Make (Rpc_intf)
  module Libp2p = Libp2p.Make (Rpc_intf)
end
