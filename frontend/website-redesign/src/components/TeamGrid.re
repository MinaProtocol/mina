module Styles = {
  open Css;
  let headerCopy =
    style([media(Theme.MediaQuery.desktop, [width(`rem(42.))])]);

  let header = merge([Theme.Type.h2, style([marginBottom(`rem(0.5))])]);

  let sectionSubhead =
    merge([
      Theme.Type.sectionSubhead,
      style([
        fontSize(`px(19)),
        lineHeight(`rem(1.75)),
        marginBottom(`rem(2.93)),
        letterSpacing(`pxFloat(-0.4)),
      ]),
    ]);

  let grid =
    style([
      display(`grid),
      paddingTop(`rem(1.)),
      gridTemplateColumns([`rem(10.), `rem(10.)]),
      gridAutoRows(`rem(17.3)),
      gridColumnGap(`rem(1.)),
      gridRowGap(`rem(1.)),
      media(
        Theme.MediaQuery.tablet,
        [
          gridTemplateColumns([
            `rem(10.),
            `rem(10.),
            `rem(10.),
            `rem(10.),
          ]),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          gridTemplateColumns([
            `rem(11.),
            `rem(11.),
            `rem(11.),
            `rem(11.),
            `rem(11.),
            `rem(11.),
          ]),
        ],
      ),
    ]);
};

[@react.component]
let make = (~profiles, ~switchModalState, ~setCurrentIndexAndMembers) => {
  <>
    <div className=Styles.headerCopy>
      <h2 className=Styles.header> {React.string("Meet the Team")} </h2>
      <p className=Styles.sectionSubhead>
        {React.string(
           "Mina is an inclusive open source protocol uniting teams and technicians from San Francisco and around the world.",
         )}
      </p>
    </div>
    <div className=Styles.grid>
      {React.array(
         profiles
         |> Array.map((member: ContentType.GenericMember.t) => {
              <div
                key={member.name}
                onClick={_ => {
                  switchModalState();
                  setCurrentIndexAndMembers(member, profiles);
                }}>
                <SmallCard member />
              </div>
            }),
       )}
    </div>
  </>;
};
