module Styles = {
  open Css;
  let memberContainer =
    style([
      height(`rem(17.)),
      width(`rem(11.)),
      color(orange),
      hover([
        display(`flex),
        flexDirection(`column),
        alignItems(`center),
        justifyContent(`center),
        transform(`scale((1.3, 1.3))),
        padding(`rem(1.)),
        backgroundColor(Theme.Colors.digitalBlack),
        selector("> div > h5", [color(white)]),
        selector("> p", [color(white)]),
      ]),
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
let make =
    (
      ~member: ContentType.TeamProfile.t,
      ~switchModalState=_ => (),
      ~setCurrentMemberIndex,
      ~index,
    ) => {
  <div className=Styles.memberContainer>
    <img className=Styles.image src={member.image.fields.file.url} />
    <div className=Styles.flexRow>
      <h5 className=Styles.name> {React.string(member.name)} </h5>
      <span
        className=Styles.icon
        onClick={_ => {
          switchModalState();
          setCurrentMemberIndex(_ => index);
        }}>
        <Icon kind=Icon.Plus />
      </span>
    </div>
    <p className=Styles.title> {React.string(member.title)} </p>
  </div>;
};
