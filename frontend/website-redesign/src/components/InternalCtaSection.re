module Item = {
  type t = {
    title: string,
    img: string,
    snippet: string,
  };

  module Styles = {
    open Css;

    let container =
      style([
        maxWidth(`rem(29.)),
        marginTop(`rem(3.)),
        marginBottom(`rem(3.)),
        media(
          Theme.MediaQuery.notMobile,
          [marginTop(`rem(8.)), marginBottom(`rem(8.125))],
        ),
      ]);

    let headerSpacing = style([marginBottom(`rem(2.3125))]);

    let image =
      style([
        width(`percent(100.)),
        height(`rem(16.125)),
        unsafe("objectFit", "cover"),
        marginBottom(`rem(1.0625)),
        media(
          Theme.MediaQuery.notMobile,
          [width(`rem(29.)), height(`rem(16.125))],
        ),
      ]);
  };

  [@react.component]
  let make = (~item) => {
    <div className=Styles.container>
      <h2 className={Css.merge([Theme.Type.h2, Styles.headerSpacing])}>
        {React.string(item.title)}
      </h2>
      <img className=Styles.image src={item.img} />
      <p className=Theme.Type.paragraph> {React.string(item.snippet)} </p>
      <div className=ListModule.Listing.ListingStyles.link>
        <span> {React.string("Read more")} </span>
        <Icon kind=Icon.ArrowRightMedium />
      </div>
    </div>;
  };
};

module Styles = {
  open Css;

  let backgroundContainer = (backgroundImg: Theme.backgroundImage) =>
    style([
      backgroundImage(`url(backgroundImg.mobile)),
      backgroundSize(`cover),
      media(
        Theme.MediaQuery.tablet,
        [backgroundImage(`url(backgroundImg.tablet))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [backgroundImage(`url(backgroundImg.desktop))],
      ),
    ]);

  let container =
    style([
      width(`percent(100.)),
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      media(Theme.MediaQuery.notMobile, [flexDirection(`row)]),
    ]);
};

[@react.component]
let make = (~backgroundImg, ~leftItem, ~rightItem) => {
  <div className={Styles.backgroundContainer(backgroundImg)}>
    <Wrapped>
      <div className=Styles.container>
        <Item item=leftItem />
        <Spacer width=1.5 />
        <Item item=rightItem />
      </div>
    </Wrapped>
  </div>;
};
