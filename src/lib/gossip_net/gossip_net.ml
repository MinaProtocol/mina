include Intf
module Any = Any
module Libp2p = Libp2p
module Fake = Fake

module type S = sig
  module Rpc_interface : RPC_INTERFACE

  include module type of Intf

  module Message : module type of Message

  module Any : Any.S with module Rpc_interface := Rpc_interface

  module Libp2p : Libp2p.S with module Rpc_interface := Rpc_interface

  module Fake : Fake.S with module Rpc_interface := Rpc_interface
end

module Make (Rpc_interface : RPC_INTERFACE) :
  S with module Rpc_interface := Rpc_interface = struct
  include Intf
  module Message = Message
  module Any = Any.Make (Rpc_interface)
  module Fake = Fake.Make (Rpc_interface)
  module Libp2p = Libp2p.Make (Rpc_interface)
end
