module Broadcast_pipe = Broadcast_pipe
module Linear_pipe = Linear_pipe

module Strict_pipe = struct
  include Strict_pipe
  module Replacable = Replacable_strict_pipe
end
