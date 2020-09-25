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
      Theme.Type.link,
      style([
        display(`flex),
        alignItems(`center),
        cursor(`pointer),
        marginTop(`rem(1.)),
      ]),
    ]);

  let mainListingContainer = style([
        width(`percent(100.)),
        media(Theme.MediaQuery.notMobile, [width(`percent(40.))]),
  ]);
};

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
  };

  [@react.component]
  let make = (~item: ContentType.BlogPost.t, ~mainImg) => {
    <div className=MainListingStyles.container>
      <div className=Styles.metadata>
        <span> {React.string("Press")} </span>
        <span> {React.string(" / ")} </span>
        <span> {React.string(item.date)} </span>
        <span> {React.string(" / ")} </span>
        <span> {React.string(item.author)} </span>
      </div>
      <img src=mainImg />
      <article>
        <h5 className=Styles.title> {React.string(item.title)} </h5>
        <p className=Styles.description> {React.string(item.snippet)} </p>
      </article>
      <Next.Link href="/blog/[slug]" _as={"/blog/" ++ item.slug} passHref=true>
        <div className=Styles.link>
          <span> {React.string("Read more")} </span>
          <Icon kind=Icon.ArrowRightMedium />
        </div>
      </Next.Link>
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
  let make = (~items) => {
    items
    |> Array.map((item: ContentType.BlogPost.t) => {
         <div className=ListingStyles.container key={item.title}>
           <div className=Styles.metadata>
             <span> {React.string("Press")} </span>
             <span> {React.string(" / ")} </span>
             <span> {React.string(item.date)} </span>
             <span> {React.string(" / ")} </span>
             <span> {React.string(item.author)} </span>
           </div>
           <h5 className=Styles.title> {React.string(item.title)} </h5>
           <Next.Link
             href="/blog/[slug]" _as={"/blog/" ++ item.slug} passHref=true>
             <div className=ListingStyles.link>
               <span> {React.string("Read more")} </span>
               <Icon kind=Icon.ArrowRightMedium />
             </div>
           </Next.Link>
         </div>
       })
    |> React.array;
  };
};

[@react.component]
let make = (~items, ~mainImg) => {
  <Wrapped>
    <div className=Styles.container>
      {switch (Belt.Array.get(items, 0)) {
       | Some(item) => (
         <div className=Styles.mainListingContainer >
           <MainListing item mainImg />
         </div>
       )
       | None =>
         <div className=Theme.Type.label> {React.string("Loading...")} </div>
       }}
      <div className=Styles.listingContainer>
        <Listing items={Belt.Array.slice(items, ~offset=1, ~len=3)} />
      </div>
    </div>
  </Wrapped>;
};
