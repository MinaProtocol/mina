module Row = {
  type backgroundType =
    | Image(string)
    | Color(Css.color);

  type buttonType = {
    buttonColor: Css.color,
    buttonTextColor: Css.color,
    buttonText: string,
    dark: bool,
    href: [ | `External(string) | `Internal(string)],
  };

  type header = {
    kind: string,
    date: string,
    author: string,
  };

  type label = {
    labelColor: Css.color,
    labelText: string,
    href: [ | `External(string) | `Internal(string)],
  };

  type link =
    | Button(buttonType)
    | Label(label);

  type t = {
    header: option(header),
    title: string,
    description: string,
    textColor: Css.color,
    image: string,
    background: backgroundType,
    contentBackground: backgroundType,
    link,
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

  let container =
    style([
      position(`relative),
      width(`percent(100.)),
      height(`percent(100.)),
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      media(Theme.MediaQuery.desktop, [height(`rem(41.))]),
    ]);

  let contentBlock = (contentBackground: Row.backgroundType) => {
    style([
      width(`percent(100.)),
      maxHeight(`rem(35.)),
      overflow(`scroll),
      unsafe("height", "fit-content"),
      margin2(~h=`rem(5.), ~v=`zero),
      display(`flex),
      flexDirection(`column),
      alignItems(`flexStart),
      justifyContent(`spaceBetween),
      padding(`rem(2.)),
      backgroundSize(`cover),
      media(
        Theme.MediaQuery.notMobile,
        [width(`percent(100.)), margin(`zero), overflow(`hidden)],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          position(`absolute),
          bottom(`percent(25.)),
          top(`inherit_),
          right(`zero),
          width(`rem(29.)),
        ],
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
    merge([
      Theme.Type.sectionSubhead,
      style([
        overflow(`hidden),
        marginTop(`rem(1.)),
        media(
          Theme.MediaQuery.desktop,
          [
            unsafe("display", "-webkit-box"),
            unsafe("-webkit-line-clamp", "5"),
            unsafe("-webkit-box-orient", "vertical"),
          ],
        ),
      ]),
    ]);

  let image =
    style([
      width(`percent(100.)),
      height(`percent(100.)),
      maxHeight(`rem(53.)),
      unsafe("objectFit", "cover"),
      media(
        Theme.MediaQuery.tablet,
        [height(`rem(30.)), width(`percent(100.))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          maxWidth(`rem(53.)),
          paddingTop(`rem(8.)),
          height(`percent(110.)),
          width(`percent(80.)),
          position(`absolute),
          left(`zero),
          bottom(`zero),
        ],
      ),
    ]);

  let metadata = merge([Theme.Type.metadata, style([color(white)])]);
};

[@react.component]
let make = (~row: Row.t, ~children=?) => {
  <div className={Styles.singleRowBackground(row.background)}>
    <Wrapped>
      <div className=Styles.container>
        <img src={row.image} className=Styles.image />
        <div className={Styles.contentBlock(row.contentBackground)}>
          <div className={Styles.copyText(row.textColor)}>
            {switch (row.header) {
             | Some(header) =>
               <>
                 <Rule color=Theme.Colors.white />
                 <Spacer height=1. />
                 <div className=Styles.metadata>
                   <span> {React.string(header.kind)} </span>
                   <span> {React.string(" / ")} </span>
                   <span> {React.string(header.date)} </span>
                   <span> {React.string(" / ")} </span>
                   <span> {React.string(header.author)} </span>
                 </div>
               </>
             | None => React.null
             }}
            <Spacer height=1.5 />
            <h2 className=Theme.Type.h2> {React.string(row.title)} </h2>
            <p className=Styles.description>
              {React.string(row.description)}
            </p>
          </div>
          <div className=Css.(style([marginTop(`rem(1.))]))>
            {switch (row.link) {
             | Button(button) =>
               <Button
                 textColor={button.buttonTextColor}
                 bgColor={button.buttonColor}
                 dark={button.dark}
                 href={button.href}>
                 <span className=Styles.buttonText>
                   {React.string(button.buttonText)}
                   <Icon kind=Icon.ArrowRightSmall size=1.5 />
                 </span>
               </Button>
             | Label(label) =>
               <Button.Link href={label.href}>
                 <span>
                   <Spacer height=1. />
                   <span className=Theme.Type.buttonLink>
                     <span> {React.string(label.labelText)} </span>
                     <Icon kind=Icon.ArrowRightMedium />
                   </span>
                 </span>
               </Button.Link>
             }}
          </div>
        </div>
      </div>
      {switch (children) {
       | Some(children) => children
       | None => <> </>
       }}
    </Wrapped>
  </div>;
};
