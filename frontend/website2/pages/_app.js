import React from "react";
import App, { Container } from "next/app";
import TagManager from "react-gtm-module";

const tagManagerArgs = {
  id: "GTM-5CNVBLB"
};

class MyApp extends App {
  componentDidMount() {
    TagManager.initialize(tagManagerArgs);
  }

  render() {
    const { Component, pageProps } = this.props;
    return (
      <Container>
        <Component {...pageProps} />
      </Container>
    );
  }
}

export default MyApp;
