[@bs.module "./translations/en.json"]
external en: array(ReactIntl.translation) = "default";
[@bs.module "./translations/vn.json"]
external vn: array(ReactIntl.translation) = "default";

type locale =
  | En
  | Vn;

let all = [|En, Vn|];

let toString =
  fun
  | En => "en"
  | Vn => "vn";

let translations =
  fun
  | En => en
  | Vn => vn;