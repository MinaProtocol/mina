### Build status

| Develop | Berkeley | Compatible | 
| ------- | -------- | ---------- |
| [![Build status - develop](https://badge.buildkite.com/0c47452f3ea619d3217d388e0de522b218db28c3e161887a9a.svg?branch=develop)](https://buildkite.com/o-1-labs-2/mina-end-to-end-nightlies) | [![Build status - berkeley](https://badge.buildkite.com/0c47452f3ea619d3217d388e0de522b218db28c3e161887a9a.svg?branch=berkeley)](https://buildkite.com/o-1-labs-2/mina-end-to-end-nightlies) | [![Build status - compatible](https://badge.buildkite.com/0c47452f3ea619d3217d388e0de522b218db28c3e161887a9a.svg?branch=compatible)](https://buildkite.com/o-1-labs-2/mina-end-to-end-nightlies)

<a href="https://minaprotocol.com">
  <img src="https://github.com/MinaProtocol/docs/blob/main/public/static/img/svg/mina-wordmark-redviolet.svg?raw=true&sanitize=true" width="350" alt="Mina logo">
</a>

# Mina

Mina is the first cryptocurrency with a lightweight, constant-sized blockchain. This is the main source code repository for the Mina project and contains code for the OCaml protocol implementation, the [Mina Protocol website](https://minaprotocol.com), and wallet. Enjoy!

## Notes

Mina is still under active development and APIs are evolving. If you build on the APIs, be aware that breaking changes can occur.

The Mina implementation of the Rosetta API offers a more stable and useful interface for retrieving the blockchain's state. Rosetta is run as a separate process and it relies on an archive being connected to a node. The source code for the archive and Rosetta implementation are in [src/app/archive](https://github.com/MinaProtocol/mina/tree/develop/src/app/archive) and [src/app/rosetta](https://github.com/MinaProtocol/mina/tree/develop/src/app/rosetta). Be sure to follow updates in the project if these resources are relocated. 

## What is Mina?

### Mina Walkthrough

- [Mina Protocol](https://docs.minaprotocol.com/) documentation
- [Installing and using a third-party wallet](https://docs.minaprotocol.com/using-mina/install-a-wallet)
- [Sending a Payment using Mina's CLI](https://docs.minaprotocol.com/node-operators/sending-a-payment)
- [Become a Node Operator](https://minaprotocol.com/docs/getting-started/)

### Technical Papers

- [Mina Whitepaper](https://eprint.iacr.org/2020/352.pdf)

### Blog

- [Mina Protocol Blog](https://minaprotocol.com/blog.html)

## Contributing

For information on how to make technical and non-technical contributions, see the repository contributing guidelines in [CONTRIBUTING](https://github.com/MinaProtocol/mina/blob/develop/CONTRIBUTING.md) and the [Contributing Guide](https://docs.minaprotocol.com/node-developers/contributing) docs.

## Developers

The [Node Developers](https://docs.minaprotocol.com/node-developers) docs contain helpful information about contributing code to Mina and using Mina APIs to build applications.

### Quick Links

- [Developer README](README-dev.md)
- [Running a demo node](docs/demo.md)
- [Lifecycle of a payment](https://docs.minaprotocol.com/node-operators/lifecycle-of-a-payment)

## Community

- Join the public Mina Protocol [Discord server](https://discord.gg/minaprotocol). Please come by if you need help or have any questions.
- Participate in our [online communities](https://docs.minaprotocol.com/participate/online-communities).
- Get the latest updates by signing up for the Mina newsletter. Select [SIGN UP FOR NEWSLETTER](https://minaprotocol.com/) on the home page of the Mina Protocol website.

## License

[Apache 2.0](LICENSE)

Commits older than 2018-10-03 do not have a [LICENSE](LICENSE) file or this notice, but are distributed under the same terms.
