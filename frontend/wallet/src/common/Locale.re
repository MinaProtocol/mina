external jsonToTranslations: Js.Json.t => array(ReactIntl.translation) =
  "%identity";
[@bs.val] [@bs.scope "window"]
external getTranslation: string => string = "getTranslation";

// Add a new language by assigning it a constructor and a language code
type locale =
  | En
  | Vn;

let toString =
  fun
  | En => "en"
  | Vn => "vn";

let fileToReactIntl = name => {
  let file = getTranslation(name);
  jsonToTranslations(Js.Json.parseExn(file));
};

// getTranslations reads a json file and parses it into a ReactIntl data structure
let getTranslations =
  fun
  | En => [||]
  | Vn => fileToReactIntl("vn");

// translationsToDict coerces the JSON translation files into a valid data structure
let translationsToDict = (translations: array(ReactIntl.translation)) => {
  translations->Belt.Array.reduce(
    Js.Dict.empty(),
    (dict, entry) => {
      dict->Js.Dict.set(
        entry##id,
        switch (entry##message->Js.Nullable.toOption) {
        | None
        | Some("") => entry##defaultMessage
        | Some(message) => message
        },
      );
      dict;
    },
  );
};

type action =
  | SetLocale(locale);

let useLocale = () => {
  let initialState = En;

  let intlReducer = (_, action) =>
    switch (action) {
    | SetLocale(locale) => locale
    };

  let (locale, dispatchLocale) = React.useReducer(intlReducer, initialState);

  (locale, dispatchLocale);
};