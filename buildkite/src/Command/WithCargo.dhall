let withCargo
    : Text -> Text
    = \(str : Text) -> "export PATH=\"/home/opam/.cargo/bin:\$PATH\" && " ++ str

in  { withCargo = withCargo }
