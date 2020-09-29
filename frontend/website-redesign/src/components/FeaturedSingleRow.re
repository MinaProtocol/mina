module Row = {
  type rowType =
    | ImageRightCopyLeft
    | ImageLeftCopyRight;

  type backgroundType =
    | Image(string)
    | Color(Css.color);

  type buttonType = {
    buttonColor: Css.color,
    buttonTextColor: Css.color,
    buttonText: string,
    dark: bool,
    href: [`External(string) | `Internal(string)],
  };

  type t = {
    rowType,
    copySize: [ | `Large | `Small],
    title: string,
    description: string,
    textColor: Css.color,
    image: string,
    background: backgroundType,
    contentBackground: backgroundType,
    button: buttonType,
  };
};

module SingleRow = {
  module RowStyles = {
    open Css;

    let container =
      style([
        position(`relative),
        width(`percent(100.)),
        height(`rem(41.)),
        display(`flex),
        flexDirection(`column),
        alignItems(`center),
      ]);

    let contentBlock = (size, contentBackground: Row.backgroundType) => {
      let additionalNotMobileStyles =
        switch (size) {
        | `Large => []
        | `Small => [bottom(`percent(35.))]
        };
      style([
        position(`absolute),
        width(`rem(21.)),
        maxHeight(`rem(35.)),
        overflow(`scroll),
        unsafe("height", "fit-content"),
        margin2(~h=`rem(5.), ~v=`zero),
        display(`flex),
        flexDirection(`column),
        alignItems(`flexStart),
        justifyContent(`spaceBetween),
        padding(`rem(3.)),
        important(backgroundSize(`cover)),
        media(
          Theme.MediaQuery.notMobile,
          [margin(`zero), overflow(`hidden), ...additionalNotMobileStyles],
        ),
        switch (contentBackground) {
        | Image(url) => backgroundImage(`url(url))
        | Color(color) => backgroundColor(color)
        },
      ]);
    };

    let copyText = textColor => {
      style([
        display(`flex),
        flexDirection(`column),
        alignItems(`flexStart),
        selector("h2,p", [color(textColor)]),
        selector(
          "p",
          [Theme.Typeface.monumentGroteskMono, letterSpacing(`px(-1))],
        ),
      ]);
    };

    let buttonText =
      style([
        display(`flex),
        justifyContent(`spaceBetween),
        alignItems(`center),
        width(`percent(100.)),
        fontSize(`rem(0.7)),
      ]);

    let description =
      merge([Theme.Type.sectionSubhead, style([marginTop(`rem(1.))])]);

    let image =
      style([
        position(`absolute),
        width(`percent(100.)),
        maxWidth(`rem(53.)),
        paddingTop(`rem(8.)),
        bottom(`zero),
        media(
          Theme.MediaQuery.tablet,
          [width(`percent(80.))],
        ),
        media(
          Theme.MediaQuery.desktop,
          [width(`percent(100.))],
        ),
      ]);
  };
  module ImageLeftCopyRight = {
    module Styles = {
      open Css;

      let image =
        merge([
          RowStyles.image,
          style([
            left(`zero),
            media(Theme.MediaQuery.notMobile, [bottom(`zero)]),
          ]),
        ]);

      let contentBlock = (size, backgroundImg) => {
        merge([
          RowStyles.contentBlock(size, backgroundImg),
          style([
            top(`rem(12.6)),
            bottom(`percent(6.)),
            media(
              Theme.MediaQuery.tablet,
              [bottom(`zero), top(`inherit_), right(`zero), width(`rem(29.))],
            ),
          ]),
        ]);
      };
    };

    [@react.component]
    let make = (~row: Row.t) => {
      <div className=RowStyles.container>
        <img src={row.image} className=Styles.image />
        <div
          className={Styles.contentBlock(row.copySize, row.contentBackground)}>
          <div className={RowStyles.copyText(row.textColor)}>
            <h2 className=Theme.Type.h2> {React.string(row.title)} </h2>
            <p className=RowStyles.description>
              {React.string(row.description)}
            </p>
          </div>
          <div className=Css.(style([marginTop(`rem(1.))]))>
            <Button
              bgColor={row.button.buttonColor}
              dark={row.button.dark}
              href={row.button.href}>
              <span className=RowStyles.buttonText>
                {React.string(row.button.buttonText)}
                <Icon kind=Icon.ArrowRightMedium size=1.5 />
              </span>
            </Button>
          </div>
        </div>
      </div>;
    };
  };

  module ImageRightCopyLeft = {
    module Styles = {
      open Css;

      let image =
        merge([
          RowStyles.image,
          style([
            right(`zero),
            bottom(`zero),
            media(Theme.MediaQuery.notMobile, [bottom(`zero)]),
          ]),
        ]);

      let contentBlock = (size, contentBackground) => {
        merge([
          RowStyles.contentBlock(size, contentBackground),
          style([
            top(`rem(12.6)),
            media(
              Theme.MediaQuery.tablet,
              [left(`zero), width(`rem(32.))],
            ),
          ]),
        ]);
      };

      let buttonText = buttonColor => {
        merge([RowStyles.buttonText, style([color(buttonColor)])]);
      };
    };

    [@react.component]
    let make = (~row: Row.t) => {
      <div className=RowStyles.container>
        <img src={row.image} className=Styles.image />
        <div
          className={Styles.contentBlock(row.copySize, row.contentBackground)}>
          <div className={RowStyles.copyText(row.textColor)}>
            <h2 className=Theme.Type.h2> {React.string(row.title)} </h2>
            <p className=RowStyles.description>
              {React.string(row.description)}
            </p>
          </div>
          <div className=Css.(style([marginTop(`rem(1.))]))>
              <Button
                bgColor={row.button.buttonColor}
                dark={row.button.dark}
                href={row.button.href}>
                <span className={Styles.buttonText(row.button.buttonTextColor)}>
                  {React.string(row.button.buttonText)}
                  <span className=Css.(style([marginTop(`rem(0.8))]))>
                    <Icon kind=Icon.ArrowRightSmall />
                  </span>
                </span>
              </Button>
          </div>
        </div>
      </div>;
    };
  };
};

module Styles = {
  open Css;

  let singleRowBackground = (backgroundImg: Row.backgroundType) =>
    style([
      minHeight(`rem(32.5)),
      width(`percent(100.)),
      important(backgroundSize(`cover)),
      switch (backgroundImg) {
      | Image(url) => backgroundImage(`url(url))
      | Color(color) => backgroundColor(color)
      },
    ]);
};

[@react.component]
let make = (~row: Row.t, ~children=?) => {
  <div className={Styles.singleRowBackground(row.background)}>
    <Wrapped>
      {switch (row.rowType) {
       | ImageLeftCopyRight => <SingleRow.ImageLeftCopyRight row />
       | ImageRightCopyLeft => <SingleRow.ImageRightCopyLeft row />
       }}
      {switch (children) {
       | Some(children) => children
       | None => <> </>
       }}
    </Wrapped>
  </div>;
};
