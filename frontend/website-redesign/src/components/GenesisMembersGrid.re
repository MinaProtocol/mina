module Styles = {
  open Css;

  let genesisHeader = merge([Theme.Type.h2, style([])]);
  let genesisCopy =
    style([
      unsafe("grid-area", "1 /1 / span 1 / span 2"),
      media(Theme.MediaQuery.tablet, [width(`rem(34.))]),
    ]);
  let sectionSubhead =
    merge([
      Theme.Type.sectionSubhead,
      style([
        fontSize(`px(19)),
        lineHeight(`rem(1.75)),
        marginTop(`rem(0.5)),
        marginBottom(`rem(2.)),
        letterSpacing(`pxFloat(-0.4)),
      ]),
    ]);
  let grid =
    style([
      marginTop(`rem(1.)),
      display(`grid),
      paddingTop(`rem(1.)),
      gridTemplateColumns([`rem(10.), `rem(10.)]),
      gridAutoRows(`rem(17.3)),
      gridColumnGap(`rem(1.)),
      gridRowGap(`rem(1.)),
      media(
        Theme.MediaQuery.tablet,
        [gridTemplateColumns([`repeat((`num(3), `rem(10.)))])],
      ),
      media(
        Theme.MediaQuery.desktop,
        [gridTemplateColumns([`repeat((`num(5), `rem(11.)))])],
      ),
    ]);
};

[@react.component]
let make = (~genesisMembers, ~switchModalState, ~setCurrentIndexAndMembers) => {
  <>
    <Spacer height=3. />
    <div className=Styles.genesisCopy>
      <h2 className=Styles.genesisHeader>
        {React.string("Genesis Members")}
      </h2>
      <p className=Styles.sectionSubhead>
        {React.string(
           "Meet the node operators, developers, and community builders making Mina happen.",
         )}
      </p>
    </div>
    <div className=Styles.grid>
      {React.array(
         genesisMembers
         |> Array.map((member: ContentType.GenericMember.t) => {
              <div
                key={member.name}
                onClick={_ => {
                  switchModalState();
                  setCurrentIndexAndMembers(member, genesisMembers);
                }}>
                <SmallCard member />
              </div>
            }),
       )}
    </div>
  </>;
};
