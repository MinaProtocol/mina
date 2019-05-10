type context = {
  settings: option(Settings.t),
  setSettings: Settings.t => unit,
};

let initialContext = {settings: None, setSettings: _ => ()};

let context = React.createContext(initialContext);

let make = context->React.Context.provider;

[@bs.obj]
external makeProps:
  (~value: context, ~children: React.element, ~key: string=?, unit) =>
  {
    .
    "value": context,
    "children": React.element,
  } =
  "";
