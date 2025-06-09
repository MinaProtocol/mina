module Broadcast_pipe = Broadcast_pipe
module Linear_pipe = Linear_pipe
module Choosable_synchronous_pipe = Choosable_synchronous_pipe

module Strict_pipe = struct
  include Strict_pipe
  module Swappable = Swappable_strict_pipe
end
