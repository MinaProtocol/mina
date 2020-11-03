module Styles = {
  open Css;
  let container =
    style([
      height(`px(1138)),
      width(`percent(100.)),
      backgroundColor(Theme.Colors.digitalBlack),
    ]);

  let contentContainer =
    style([
      display(`flex),
      alignItems(`center),
      overflowX(`hidden),
      width(`vw(100.)),
      selector("> div", [marginLeft(`rem(1.))]),
    ]);

  let contentCard = style([]);

  let rule = style([marginTop(`rem(6.))]);
};

module Arrow = {
  [@react.component]
  let make = (~icon, ~onClick) => {
    <div onClick> <Icon kind=icon /> </div>;
  };
};

module Slide = {
  [@react.component]
  let make = (~profiles: array(ContentType.GenesisProfile.t)) => {
    <div className=Styles.contentContainer>
      {profiles
       |> Array.map((p: ContentType.GenesisProfile.t) => {
            <div key={p.name} className=Styles.contentCard>
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
            </div>
          })
       |> React.array}
    </div>;
  };
};

[@react.component]
let make = (~profiles: array(ContentType.GenesisProfile.t)) => {
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

  <div className=Styles.container>
    <Arrow icon=Icon.ArrowLeftLarge onClick=prevSlide />
    <Arrow icon=Icon.ArrowRightLarge onClick=nextSlide />
    <Slide profiles=currentProfiles />
  </div>;
};
