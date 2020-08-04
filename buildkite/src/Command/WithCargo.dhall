let withCargo
    : Text -> Text
    = \(str : Text) -> "export PATH=\"\$HOME/.cargo/bin:\$PATH\" && " ++ str

in  { withCargo = withCargo }
