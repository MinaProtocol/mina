include Intf
module Any = Any
module Real = Real
module Fake = Fake

module type S = sig
  module Rpc_intf : Coda_base.Rpc_intf.Rpc_interface_intf

  include module type of Intf

  module Message : module type of Message

  module Any : Any.S with module Rpc_intf := Rpc_intf

  module Real : Real.S with module Rpc_intf := Rpc_intf

  module Fake : Fake.S with module Rpc_intf := Rpc_intf
end

module Make (Rpc_intf : Coda_base.Rpc_intf.Rpc_interface_intf) :
  S with module Rpc_intf := Rpc_intf = struct
  include Intf
  module Message = Message
  module Any = Any.Make (Rpc_intf)
  module Fake = Fake.Make (Rpc_intf)
  module Real = Real.Make (Rpc_intf)
end
