module Styles = {
  open Css;
  let memberContainer =
    style([
      height(`rem(17.)),
      width(`rem(11.)),
      color(orange),
      cursor(`pointer),
    ]);
  let image = style([width(`percent(100.)), marginBottom(`rem(1.))]);
  let name =
    merge([
      Theme.Type.h5,
      style([color(black), important(fontSize(`px(18)))]),
    ]);
  let title =
    merge([
      Theme.Type.contributorLabel,
      style([color(black), fontSize(`px(12)), maxWidth(`rem(10.))]),
    ]);
  let flexRow =
    style([
      display(`flex),
      flexDirection(`row),
      justifyContent(`spaceBetween),
      width(`percent(100.)),
    ]);

  let icon = style([cursor(`pointer)]);
};

[@react.component]
let make = (~member: ContentType.GenericMember.t) => {
  <div className=Styles.memberContainer>
    <img className=Styles.image src={member.image.fields.file.url} />
    <div className=Styles.flexRow>
      <h5 className=Styles.name> {React.string(member.name)} </h5>
      <span className=Styles.icon> <Icon kind=Icon.Plus /> </span>
    </div>
    <p className=Styles.title> {React.string(member.title)} </p>
  </div>;
};
