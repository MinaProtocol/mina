module Styles = {
  open Css;
  let container =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      flexDirection(`column),
      alignItems(`center),
      width(`percent(100.)),
      height(`percent(100.)),
      media(
        Theme.MediaQuery.notMobile,
        [flexDirection(`row), height(`rem(32.))],
      ),
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

  let link =
    merge([Theme.Type.link, style([display(`flex), alignItems(`center)])]);
};

module MainListing = {
  module MainListingStyles = {
    open Css;
    let container =
      style([
        display(`flex),
        flexDirection(`column),
        borderTop(`px(1), `solid, Theme.Colors.digitalBlack),
        width(`percent(100.)),
        height(`percent(100.)),
        selector("img", [marginTop(`rem(1.))]),
        media(Theme.MediaQuery.notMobile, [width(`percent(40.))]),
      ]);
  };

  [@react.component]
  let make = () => {
    <div className=MainListingStyles.container>
      <div className=Theme.Type.metadata>
        <span> {React.string("Press")} </span>
        <span> {React.string(" / ")} </span>
        <span> {React.string("16 Jun 2020")} </span>
        <span> {React.string(" / ")} </span>
        <span> {React.string("Coindesk")} </span>
      </div>
      <img src="/static/img/ArticleImage.png" />
      <article>
        <h5 className=Styles.title>
          {React.string(
             "Coda Protocol (now Mina) Sets aside $2.1M in tokens for Dev gains",
           )}
        </h5>
        <p className=Styles.description>
          {React.string(
             {js|The new grant program, which would be paid out using Coda’s (now Mina’s) tokens, is open to any project that helps develop the protocol, build tooling, organize meetups or create content.|js},
           )}
        </p>
      </article>
      <Next.Link href="/">
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

    let link =
      merge([
        Styles.link,
        style([marginTop(`rem(0.5)), marginBottom(`rem(1.))]),
      ]);
  };

  [@react.component]
  let make = () => {
    <div className=ListingStyles.container>
      <div className=Theme.Type.metadata>
        <span> {React.string("Press")} </span>
        <span> {React.string(" / ")} </span>
        <span> {React.string("16 Jun 2020")} </span>
        <span> {React.string(" / ")} </span>
        <span> {React.string("Coindesk")} </span>
      </div>
      <h5 className=Styles.title>
        {React.string(
           "Coda Protocol (now Mina) Sets aside $2.1M in tokens for Dev gains",
         )}
      </h5>
      <Next.Link href="/">
        <div className=ListingStyles.link>
          <span> {React.string("Read more")} </span>
          <Icon kind=Icon.ArrowRightMedium />
        </div>
      </Next.Link>
    </div>;
  };
};

[@react.component]
let make = () => {
  <Wrapped>
    <div className=Styles.container>
      <MainListing />
      <div className=Styles.listingContainer>
        <Listing />
        <Listing />
        <Listing />
      </div>
    </div>
  </Wrapped>;
};
