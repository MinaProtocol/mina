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
  (client, Js.t('args)) => Js.Promise.t(ContentType.System.entries('entry)) =
  "getEntries";
