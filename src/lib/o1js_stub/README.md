# `o1js-stub` 

## Overview

The primary purpose of the `o1js-stub` module is to maintain the compatibility of the Mina core. This stub module, which contains only a dune file to compile Mina dependencies, replicates the dependency structure of [`o1js`](https://github.com/o1-labs/o1js), specifically the [OCaml](https://github.com/o1-labs/o1js-bindings/blob/main/ocaml/lib/dune) dependencies but without the complexity of the full implementation.

## Rationale

In the development of Mina, there have been instances where the JavaScript build broke unexpectedly. This was often due to the inadvertent addition of popular OCaml libraries that are incompatible with JavaScript compilation. To prevent such scenarios and ensure the robustness of the Mina core in a JS environment, `o1js-stub` plays a crucial role.

## Key Features

- **Dependency Mirror:** `o1js-stub` mirrors the dependency profile of `o1js` module. This ensures that any dependencies which could break JS compilation are flagged early.
  
- **Continuous Integration Checks:** In the Mina CI pipeline, `o1js-stub` is subjected to compilation checks using Dune. This is a critical step to verify that the module, along with its dependencies, remains JS-compilable.

## Integration in Mina CI

The integration of `o1js-stub` in the Mina Continuous Integration (CI) process serves as a gatekeeper to prevent the introduction of JS-incompatible dependencies into the Mina core. During CI, the module is compiled, and any failure in this process would indicate potential compatibility issues, thereby safeguarding the JS build.

## Usage

For Mina developers, the introduction of `o1js-stub` should be largely transparent. However, it's important to be aware of its existence, especially when considering the addition or modification of dependencies that might affect the JavaScript build.

Developers should ensure that any changes in the dependencies of modules related to `o1js-stub` do not introduce JS-incompatibility. Any such changes should be thoroughly tested locally and will be automatically verified in the CI pipeline.

