open Core_kernel

let () = 
  let json = Genesis_constants.Compiled.Inputs.to_yojson Genesis_constants.Compiled.Inputs.t in
  let json_str = Yojson.Safe.pretty_to_string json in
  let oc = Out_channel.create "genesis_constants.json" in
  Out_channel.output_string oc json_str;
  Out_channel.close oc