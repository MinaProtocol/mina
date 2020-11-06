module Styles = {
  open Css;
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
let make =
    (~profiles, ~switchModalState,  ~setCurrentMemberIndex) => {
  <div className=Styles.grid>
    {React.array(
       Array.mapi(
         (index, member: ContentType.TeamProfile.t) => {
           <div key={member.name}>
             <TeamMember index member switchModalState setCurrentMemberIndex />
           </div>
         },
         profiles,
       ),
     )}
  </div>;
};
