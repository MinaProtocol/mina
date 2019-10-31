

[@react.component]
let make = () => {
  <div> 
    /* <ReasonApollo.Provider client=Apollo.client> */
      <Background/>
      <Banner time="42"/>
      <Spacer height=5.0/>
      <BlockRow/>
    /* </ReasonApollo.Provider> */
  </div>;
};
