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
        marginTop(`rem(8.)),
        marginBottom(`rem(8.125)),
      ]);

    let headerSpacing = style([marginBottom(`rem(2.3125))]);

    let contentSpacing = style([marginBottom(`rem(1.0625))]);
  };

  [@react.component]
  let make = (~item) => {
    <div className=Styles.container>
      <h2 className={Css.merge([Theme.Type.h2, Styles.headerSpacing])}>
        {React.string(item.title)}
      </h2>
      <img
        className=Styles.contentSpacing
        src={item.img}
        width="464"
        height="258"
      />
      <p
        className={Css.merge([
          Theme.Type.sectionSubhead,
          Styles.contentSpacing,
        ])}>
        {React.string(item.snippet)}
      </p>
      <div className=ListModule.Listing.ListingStyles.link>
        <span> {React.string("Read more")} </span>
        <Icon kind=Icon.ArrowRightMedium />
      </div>
    </div>;
  };
};

module Styles = {
  open Css;
  let container = style([display(`flex), justifyContent(`spaceBetween)]);
};

[@react.component]
let make = (~leftItem, ~rightItem) => {
  <Wrapped>
    <div className=Styles.container>
      <Item item=leftItem />
      <Item item=rightItem />
    </div>
  </Wrapped>;
};
