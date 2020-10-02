module Styles = {
  open Css;
  let container =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      flexDirection(`column),
      width(`percent(100.)),
      height(`percent(100.)),
      media(Theme.MediaQuery.notMobile, [flexDirection(`row)]),
    ]);

  let listingContainer =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      height(`percent(100.)),
    ]);

  let title = merge([Theme.Type.h5, style([marginTop(`rem(1.))])]);

  let description =
    merge([Theme.Type.paragraphSmall, style([marginTop(`rem(1.))])]);

  let metadata =
    merge([Theme.Type.metadata, style([marginTop(`rem(0.5))])]);

  let link =
    merge([
      Theme.Type.buttonLink,
      style([
        display(`flex),
        alignItems(`center),
        cursor(`pointer),
        marginTop(`rem(1.)),
      ]),
    ]);

  let mainListingContainer =
    style([
      width(`percent(100.)),
      media(Theme.MediaQuery.notMobile, [width(`percent(40.))]),
    ]);
};

type itemKind =
  | Blog
  | TestnetRetro;

module MainListing = {
  module MainListingStyles = {
    open Css;
    let container =
      style([
        display(`flex),
        flexDirection(`column),
        borderTop(`px(1), `solid, Theme.Colors.digitalBlack),
        height(`percent(100.)),
        selector("img", [marginTop(`rem(1.))]),
      ]);

    let anchor =
      style([
        textDecoration(`none)
      ]);
  };

  [@react.component]
  let make = (~item: ContentType.NormalizedPressBlog.t, ~itemKind) => {
    <div className=MainListingStyles.container>
      <div className=Styles.metadata>
        {switch (itemKind) {
         | Blog => <span> {React.string("Press")} </span>
         | TestnetRetro => <span> {React.string("Testnet Retro")} </span>
         }}
        <span> {React.string(" / ")} </span>
        <span> {React.string(item.date)} </span>
        <span> {React.string(" / ")} </span>
        <span> {React.string(item.publisher)} </span>
      </div>
      {ReactExt.fromOpt(item.image, ~f=src =>
         <img src={src.ContentType.System.fields.ContentType.Image.file.url} />
       )}
      <article>
        <h5 className=Styles.title> {React.string(item.title)} </h5>
        {ReactExt.fromOpt(item.description, ~f=copy =>
           <p className=Styles.description> {React.string(copy)} </p>
         )}
      </article>
      {let inner =
         <div className=Styles.link>
           <span> {React.string("Read more")} </span>
           <Icon kind=Icon.ArrowRightMedium />
         </div>;
       switch (item.link) {
       | `Slug(slug) =>
         <Next.Link href="/blog/[slug]" _as={"/blog/" ++ slug} passHref=true>
           inner
         </Next.Link>
       | `Remote(href) =>
         <a className=MainListingStyles.anchor href> inner </a>
       }}
    </div>;
  };
};

module Listing = {
  module ListingStyles = {
    open Css;
    let container =
      style([
        display(`flex),
        flexDirection(`column),
        borderTop(`px(1), `solid, Theme.Colors.digitalBlack),
        width(`percent(100.)),
        marginTop(`rem(1.)),
        media(
          Theme.MediaQuery.notMobile,
          [marginTop(`zero), width(`percent(80.))],
        ),
      ]);

    let link = merge([Styles.link, style([marginBottom(`rem(2.))])]);
  };

  [@react.component]
  let make = (~items, ~itemKind) => {
    let button = (item: ContentType.NormalizedPressBlog.t) => {
      let inner =
          <div className=ListingStyles.link>
            <span> {React.string("Read more")} </span>
            <Icon kind=Icon.ArrowRightMedium />
          </div>;
          switch (item.link) {
         | `Slug(slug) =>
          <Next.Link href="/blog/[slug]" _as={"/blog/" ++ slug} passHref=true>
            {inner}
          </Next.Link>
         | `Remote(href) =>
          <a className=MainListing.MainListingStyles.anchor href>
            {inner}
          </a>
         }
    };

    items
    |> Array.map((item: ContentType.NormalizedPressBlog.t) => {
         <div className=ListingStyles.container key={item.title}>
           <div className=Styles.metadata>
             {switch (itemKind) {
              | Blog => <span> {React.string("Press")} </span>
              | TestnetRetro => <span> {React.string("Testnet Retro")} </span>
              }}
             <span> {React.string(" / ")} </span>
             <span> {React.string(item.date)} </span>
             <span> {React.string(" / ")} </span>
             <span> {React.string(item.publisher)} </span>
           </div>
           <h5 className=Styles.title> {React.string(item.title)} </h5>
           { button(item) }
          </div>
       })
    |> React.array;
  };
};

[@react.component]
let make = (~items, ~itemKind) => {
  <Wrapped>
    <div className=Styles.container>
      {switch (Belt.Array.get(items, 0)) {
       | Some(item) =>
         <div className=Styles.mainListingContainer>
           <MainListing item itemKind />
         </div>
       | None =>
         <div className=Theme.Type.label> {React.string("Loading...")} </div>
       }}
      <div className=Styles.listingContainer>
        <Listing
          items={Belt.Array.slice(items, ~offset=1, ~len=3)}
          itemKind
        />
      </div>
    </div>
  </Wrapped>;
};
