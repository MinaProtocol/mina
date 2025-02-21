open Core_kernel

module Type = struct
  [%%versioned module Bad = struct end]
end
