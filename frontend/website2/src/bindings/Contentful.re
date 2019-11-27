let loadConfigValue = key => {
  let config = Next.getConfig().Next.publicRuntimeConfig;
  switch (Js.Dict.get(config, key)) {
  | None => failwith("Couldn't find config entry for " ++ key)
  | Some(s) => s
  };
};

let imageAPIToken = loadConfigValue("CONTENTFUL_IMAGE_TOKEN");
let spaceID = loadConfigValue("CONTENTFUL_SPACE");
let contentAPIToken = loadConfigValue("CONTENTFUL_TOKEN");

type clientArgs = {
  space: string,
  accessToken: string,
};

type client;

[@bs.module "contentful"] [@bs.val]
external createClient: clientArgs => client = "createClient";

let client =
  lazy(createClient({space: spaceID, accessToken: contentAPIToken}));

[@bs.send]
external getEntries:
  (client, Js.t('args)) => Js.Promise.t(ContentType.entries('entry)) =
  "getEntries";

// Only to be used in getInitialProps
let get = (~cache, ~key, ~query, ~fn) => {
  (
    switch (Js.Dict.get(cache, key)) {
    | Some(post) => Js.Promise.resolve(post)
    | None =>
      getEntries(Lazy.force(client), query)
      |> Js.Promise.then_((entries: ContentType.entries('a)) => {
           let post =
             switch (entries.items) {
             | [|item|] => Some(item.fields)
             | _ => None
             };
           Js.Dict.set(cache, key, post);
           Js.Promise.resolve(post);
         })
    }
  )
  |> Js.Promise.then_(v => Js.Promise.resolve(fn(v)));
};
