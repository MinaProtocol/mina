module Styles = {
  open Css;
  let container = dark =>
    style([
      height(`px(1138)),
      width(`percent(100.)),
      paddingTop(`rem(6.)),
      dark
        ? backgroundColor(Theme.Colors.digitalBlack)
        : backgroundColor(`transparent),
    ]);

  let leftWrapped =
    style([
      paddingLeft(`rem(1.5)),
      margin(`auto),
      media(
        Theme.MediaQuery.tablet,
        [maxWidth(`rem(85.0)), paddingLeft(`rem(2.5))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [maxWidth(`rem(90.0)), paddingLeft(`rem(9.5))],
      ),
    ]);

  let contentContainer =
    style([
      display(`flex),
      alignItems(`center),
      overflowX(`hidden),
      width(`vw(100.)),
      selector(" > :not(:first-child)", [marginLeft(`rem(1.))]),
    ]);

  let headerContainer =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`flexEnd),
      justifyContent(`spaceBetween),
      marginTop(`rem(3.)),
      marginBottom(`rem(6.625)),
      media(Theme.MediaQuery.notMobile, [flexDirection(`row)]),
    ]);

  let headerCopy =
    style([
      width(`percent(100.)),
      media(Theme.MediaQuery.tablet, [width(`percent(70.))]),
      media(Theme.MediaQuery.desktop, [width(`percent(50.))]),
    ]);

  let rule = style([marginTop(`rem(6.))]);

  let h2 = dark =>
    merge([
      Theme.Type.h2,
      style([dark ? color(white) : color(Theme.Colors.digitalBlack)]),
    ]);

  let paragraph = dark =>
    merge([
      Theme.Type.paragraph,
      style([dark ? color(white) : color(Theme.Colors.digitalBlack)]),
    ]);

  let buttons =
    style([
      display(`flex),
      alignItems(`center),
      justifyContent(`spaceBetween),
      marginTop(`rem(1.)),
      selector(">:first-child", [marginRight(`rem(1.))]),
      media(Theme.MediaQuery.notMobile, [marginTop(`zero)]),
    ]);

  let button = dark =>
    merge([
      Button.Styles.button(
        Theme.Colors.digitalBlack,
        Theme.Colors.white,
        Some(Theme.Colors.white),
        !dark,
        `rem(2.5),
        Some(`rem(2.5)),
        0.5,
        0.,
      ),
      style([cursor(`pointer)]),
    ]);
};

module Arrow = {
  [@react.component]
  let make = (~icon, ~onClick, ~dark) => {
    <div className={Styles.button(dark)} onClick> <Icon kind=icon /> </div>;
  };
};

module Slide = {
  [@react.component]
  let make = (~profiles: array(ContentType.GenesisProfile.t)) => {
    <div className=Styles.contentContainer>
      {profiles
       |> Array.map((p: ContentType.GenesisProfile.t) => {
            <GenesisMemberProfile
              key={p.name}
              name={p.name}
              photo={p.profilePhoto.fields.file.url}
              quote={"\"" ++ p.quote ++ "\""}
              location={p.memberLocation}
              twitter={p.twitter}
              github={p.github}
              blogPost={p.blogPost.fields.slug}
            />
          })
       |> React.array}
    </div>;
  };
};

[@react.component]
let make =
    (
      ~title,
      ~copy,
      ~dark=false,
      ~profiles: array(ContentType.GenesisProfile.t),
    ) => {
  let (currentProfiles, setCurrentProfiles) = React.useState(_ => profiles);

  let prevSlide = _ => {
    let copy = Belt.Array.copy(currentProfiles);
    switch (Js.Array.shift(copy)) {
    | Some(last) =>
      Js.Array.push(last, copy) |> ignore;
      setCurrentProfiles(_ => copy);
    | None => ()
    };
  };

  let nextSlide = _ => {
    let copy = Belt.Array.copy(currentProfiles);
    switch (Js.Array.pop(copy)) {
    | Some(last) =>
      Js.Array.unshift(last, copy) |> ignore;
      setCurrentProfiles(_ => copy);
    | None => ()
    };
  };

  <div className={Styles.container(dark)}>
    <Wrapped>
      <Rule color=Theme.Colors.white />
      <div className=Styles.headerContainer>
        <span className=Styles.headerCopy>
          <h2 className={Styles.h2(dark)}> {React.string(title)} </h2>
          <Spacer height=1. />
          <p className={Styles.paragraph(dark)}> {React.string(copy)} </p>
        </span>
        <span className=Styles.buttons>
          <Arrow icon=Icon.ArrowLeftLarge onClick=prevSlide dark />
          <Arrow icon=Icon.ArrowRightLarge onClick=nextSlide dark />
        </span>
      </div>
    </Wrapped>
    <div className=Styles.leftWrapped>
      <Slide profiles=currentProfiles />
    </div>
  </div>;
};
