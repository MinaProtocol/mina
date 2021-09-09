## Summary
[summary]: #summary

This RFC describes the design for an automated validation service which will be deployed alongside testnets. The goal is to define a system which can be quickly iterated on, from both the perspective of adding new validations and maintaining this service. As such it is important that this service supports the capabilities required to define a wide variety of different validations we would like to perform against the network on a regular basis.

## Motivation
[motivation]: #motivation

There are many things we want to validate about our testnets on a regular basis (and always before a release). Most of these validations need to be performed at various points during the network's execution. Currently, we are doing all of this validation manually (responsibility of the testnet guardian), which takes a significant amount of engineering time and distracts from other tasks. Furthermore validation errors are often caught later than they could have been since engineers are (unfortunately) not computers and won't necessarily check the each validation criteria as soon as it is available to verify. This also extends towards validations which need to be checked throughout the execution of the network, such as network forks.

The primary motivations behind building an automated validation service are to reduce validation costs to engineering time, tighten the iteration loop around stabilizing our network, give us more confidence in future public testnet releases, and to provide a route to regular CI network validations.

## Detailed design
[detailed-design]: #detailed-design

Observing the [list of validations we require for stable networks](https://www.notion.so/codaprotocol/Testnet-Validation-1705d5bf03e04d03b21a1f5724a17597), the majority of validations can be answered through a combination of log processing and graphql queries. As such, we will initially scope the design of the validation service to focus on those two aspects, while trying to create a design that isn't over-fitted to these two aspects so that we can refit parts of the architecture for validations which are outside this scope after the initial implementation is complete.

### Architecture
[detailed-design-architecture]: #detailed-design-architecture

In order to discuss the architecture for the automated validation service, we should first define how we want to interact with the automated validation service from a high level. A naive approach to the validation service would be to always enable all validations, but in order to make this service reusable in various environments (qa net, public testnet, mainnet), allow it to be horizontally scalable, and perhaps even use it as part of the integration test framework, the validation service should be configurable. The inputs to the validation service should include the following information:

- credentials to talk to various APIs (gcloud, kubernetes, discord, etc...)
- information about which network to validate
- the set of resources deployed on the network (see below for more detail on resources)
- a list of "validation queries"; each "validation query" includes:
  - the name of the validation to perform
  - a query on which resources it should be performed on

From the list of validation queries, the automated validation can solve for other information it needs to actually run, such as what log filters it needs to pull from stackdriver, what information to compute from events and state changes on the network, and what resources are scoped to each of these concepts. The architecture of the automated validation service is thus broken up and modeled as a series of concurrent "processes", which we will classify into various roles (providers, statistics, and validators), which are responsible for one piece of the entire service.

Below is a diagram which displays how the system is initialized given the validation queries and resource database. From the information computed during this initialization, the automated validation service can create the various processes and external resources (such as log sinks on google cloud) necessary to perform the requested validations on the requested resources.

![](./res/automated_validation_init_architecture.conv.tex.png)

The following diagram shows the runtime architecture of the processes in the system once initialization has been completed. Note how this diagram shows that statistics may consume multiple providers, and validations may consume multiple statistics.

![](./res/automated_validation_runtime_architecture.conv.tex.png)

#### Resources
[detailed-design-architecture-resources]: #detailed-design-architecture-resources

A deployment consists of a series of pods and containers. We define a universal abstraction for reasoning about these artifacts of a deployment, which generically call "resources". Resources are classified into different categories in an subtyping model. For example, the main resource we are interested in is a `CodaNode`. There are multiple subclasses of `CodaNode`, such as `BlockProducer`, `SnarkCoordinator`, or `Seed`. Each of these classes may have different metadata associate with instances of them. For instance, all `CodaNode` instances have a `pod_name`, and `BlockProducer` instances have additional metadata for what block producer role they are and their integer id (eg in "fish-block-producer-1", role="fish" and id=1).

Resources can be collected into queriable datasets which allow selection of resources by metadata filters or classification.

#### Providers
[detailed-design-architecture-providers]: #detailed-design-architecture-providers

Providers provide network state to the rest of the system. There are multiple kinds of providers, such as `GraphQLProviders`, which provide data from GraphQL queries on a periodic basis, and `EventProviders`/`LogProviders`, which extract events from logs. Logs can be streamed back to the automated validation service fairly easily from StackDriver by creating a log sink, pub sub topic, and one or more filter subscriptions in Google Cloud (I have tested this functionality for pull-based subscriptions, and push-based subscriptions are an easy extension of this to setup). Providers are dispatched for specific resources, and provide an internal subscription to state updates for those resources so that statistics may receive updates.

#### Statistics
[detailed-design-architecture-statistics]: #detailed-design-architecture-statistics

Statistics consume network state information from one or more providers and incrementally compute a rolling state (representing the computed statistic). Statistics are (at least in the initial design) individually scoped to resources (meaning that each statistic has a singular instance computed for each resource that is being monitored by the system). Statistics broadcast their state updates so that vlaidations can be performed on one or more statistic as values change. Statistics can also be forwarded to as prometheus metrics. Doing this would allow us to compute more meaningful network wide statistics that we cannot easily compute today without writing a program to scrape the logs after the network runs.

#### Validations
[detailed-design-architecture-validations]: #detailed-design-architecture-validations

Validations subscribe to and perform checks against one or more statistics. The result of a validation is either "this state is valid" or "this state is invalid because of X". If a validation fails, the alert system is notified of the specific validation error. Since validations can subscribe to more than one statistic at a time, they are checked concurrently to computing the values of statistics. When any of the statistics that a validation is subscribed to update, the validation is reperformed on the set of most-up-to-date statistics.

#### Alerts
[detailed-design-architecture-alerts]: #detailed-design-architecture-alerts

When validations fail, alerts can be triggered. In theory, there can be multiple backends for how alerts are surfaced to the team. As an initial scope for the project, I think that focusing on discord alerts to an internal channel which is monitored by the testnet guardian and other engineers should suffice for now. One important note here is that this service should be *loud*, but not *noisy*. This means that the service should send a notification somewhere people see it, but it should contain some logic to help limit the noise level of these alerts. We don't want to have this alerting system spam too much and make uneccessary noise, because that will just lead people to ignore it like we do much of the noise from failing CI tests. As such, a basic validation error rate limiter and timeout logic seems to be a must. By default, we should limit errors to (roughly) 5 per hour, and we can tweak this individually for each validation.

### Language Choice
[detailed-design-language-choice]: #detailed-design-language-choice

Language choice is a key component for the automated validation service design which has large ramifications on it's implementation and maintenance costs. In particular, we want to optimize for the maintenance costs of the automated validation service. There are 2 important aspects to consider when optimizing for the maintenance cost of this service: scalability and reusability. Scalability, in the context of this service, directly relates to how concurrent this system can be, since this service will be monitoring networks in the size order of 100s of nodes. Reusability relates to our ability to configure and resuse abstractions for the individual components involved in the service (resources, providers, statistics, validations). In addition to these, we also would like to choose a language which either engineers already know, or a language which would be easy for engineers to pick up without much learning overhead.

#### Languages Not Chosen

With the requirement that this system be highly concurrent (so that we don't need to spend a lot of engineering effort trying to optimize this tool), that immediately hurts the case for the main language we use currently, OCaml. OCaml comes with great benefits, such as it already being our standard language on the team and it having a good static type system, but the single threaded concurrency story in OCaml is poor, and the solutions and tooling around them (pthreads & rpc\_parallel) are either too low level and tedious to get correct or too bulky to use, making concurrenty OCaml code quite difficult to iterate on. As such, OCaml seems like the wrong choice for this system as we would spend a lot of engineering effort on just the architecture for this system (and would likely need to revisit that as we intend to scale this system up to more and more validations and larger network sizes).

Python is another language which we use, but also suffers from a poor single-threaded concurrency model. Python is a little bit easier to get concurrency going in than OCaml, but is less principled than OCaml and fully lacks type safety. Python has type annotations, but the tooling for analyzing them is poor due to they way the type annotations we designed, so most type checking can only happen as a runtime assertion. Furthermore, it's concurrency model requires manual thread yielding (or to setup your code to auto yeild on every function call), making thread starvation a much harsher and likely reality compared to OCaml.

Rust has very good concurrency and parallelism support (debatably one of the best out there today). It has strong type safety and a fantastic borrow checker model to help avoid typical memory errors when writing concurrent or parallel code. However, Rust has a very high learning curve compared to other languages due to it's borrow checker model and layer of abstraction. Being a low-level language by nature, Rust programs tend to be more verbose and difficult to design, and designing a program incorrectly up front can cause wasted work when the compiler informs you that your code isn't written correctly. Given that our engineering team is more focused to abstract functional programming than low level programming, the learning curve and barrier to entry seems even steeper since part of that includes becoming comfortable with low level memory management practices and gotchas. Due to this, and the much slower iteration cycle that Rust has compared to other languages (unless you are very good at Rust), Rust seems like the incorrect choice for this system.

#### The Ideal Platform

I believe the best language for this system is a language which runs on the BeamVM. The BeamVM is a virtual machine which is part of the Erlang Open Telecom Platform (OTP) distribution. OTP is a technology suite and set of standards which was developed by Ericsson in the late 90s. While OTP has "telecom" in the name, nothing about it is actually specific to telecom as an industry. Rather, it was built by Ericsson in the late 90s in order to solve their problems of needing a highly concurrent software system for a new ATM switch they were building. Since it was open sourced in the late 90s, Erlang OTP has seen a wide variety of uses throughout concurrenty distributed systems, most notably making strides in web development in recent years. Some examples of large projects built on the BeamVM include RabbitMQ, Facebook's chat service, WhatsApp's backend, and Amazon's EC2 database services, just to name a few.

The main advantage of the BeamVM is the concurrency model it supports, along with the efficiency it achieves when evaluating this model at runtime. Inside the BeamVM, code is separated into "processes" (not to be confused with OS-level processes), each of which is represented by a call stack and a mailbox. Processes may send messages to other processes, and block and receive messages through their mailbox. An important thing to note here is that the only state a process has is it's call stack and mailbox. This means that there is no mutable state internal to any process, immediately eliminating a large amount of bugs related to non-synchronized state access. Messages are safe and efficient to share between processes, and (without going into detail) the model by which processes block and pull information out of their incoming mailbox prevents a number of traditional "starvation" or "deadlocking" cases. Processes are organized into "supervision trees", where parent processes (called supervisors) are responsible for monitoring and restarting their children. OTP includes a set of standard abstractions around processes that fit into this "supervision tree" model, with the intention to provide fault tolerance to your concurrent architecture *by default*. This system does not eliminate concurrent bugs all together, but it limits the kind of bugs you can encounter, and provides tools to help make the system robust to errors that may occur at runtime. The BeamVM is very efficient with how it actually schedules these processes, and is typically able to evenly saturate as many CPU cores as you want it to (so long as you follow proper design patterns, which OTP makes easy).

#### The Chosen Language

Erlang is the language which was originally developed for working on the BeamVM (and as such, the two projects are heavily intertwined). Erlang is a weird language though, pulling syntatical inspiration from Prolog into a purely immutable dynamically typed functional programming language with a unique concurrency model. Since Erlang's introduction as part of the OTP system, many other languages targetting the same virtual machine have cropped up, attempting to make Erlang's programming model more approachable and easier to pick up and learn for developers. Some projects have added ML-like languages on top of Erlang and added static types along the way. However, the most popular and widely used language (which has basically superceded Erlang at this point) is Elixir.

Elixir provides an easier syntax (ruby-esque syntax), a module system, macros, and reusable mixins for code generation on top of the Erlang OTP system. It also comes with a type specification system which is built into the language and tooling which can statically analyze the type specs during compilation (not as good as proper static types, but one of the better static anlysis type systems; better than flowjs, for example, and all libraries, including stdlib and erlang libs, come with typespecs). It has a low learning curve and lots of resources for learning both the language and the concurrency model it sits on top of (the BeamVM process model). There is no mutability, it's very easy to build DSLs and OCaml functor-like patterns. This provides the ability to easily create and maintain abstractions for defining the various pieces of this system (resources, providers, statistics, validations). The concurrency model of the BeamVM means that iteration over concurrent optimizations is short and easy. Since the BeamVM unifies the entire concurrency model into one abstraction (processes), refactoring to optimize the amount of concurrency the system gets is simple since you only rewrite the code around your process and typically don't need to change details about how your process does it's job. For these reasons, Elixir seems like the best choice for building and maintaining this system in.

Elixir is easy to install on Linux and OSX (available through all major package managers). It comes with a build tool, called `mix`, which is the main way that you interact with a project. It downloads dependencies, handles configurations, runs scripts, compiles code, and executes static analysis (formatting, type checking). Running Elixir applications is pretty simple as well. All that's needed is the built BeamVM artifact and a docker container with the BeamVM installed. We don't need to consider it anytime soon for our usecases, but there is also a microkernel image for the BeamVM which supports SSH'ing directly into an interactive Elixir shell.

## Proof of Concept
[proof-of-concept]: #proof-of-concept

##### NB: The proof of concept is nearly done and will soon be put up so the implementation can be reviewed. For now, in the interest of getting this RFC in front of people, I am documenting the interface the proof of concept exposes for defining new providers, statistics, and validations.

I have fleshed out a PoC for what this system would look like in Elixir. In the PoC, we only focus on LogProviders rather than GraphQLProviders, however the latter type of Provider should be arbitrary to build. The alerting system and validation specification interface is also not fleshed out in the interest of keeping proof of concept simple. The PoC includes mixins for easily defining new resources, providers, statistics, and validations in the system. These mixins (which are included into modules using the `use` macro) expect specific functions to be implemented on the module (called "callbacks" in Erlang/Elixir), and the mixins can add additional boilerplate code to the module. For OCaml developers, Elixir's concept of a "mixin" can be thought of similarly to how we think about "functors" in OCaml (though they work differently).

In the PoC, LogProviders can be easily added by specifying the resource class and filter the LogProvider is associated with. For instance, a LogProvider which provides events for whenever new blocks are produced is defined as follows:

```elixir
defmodule LogProviders.BlockProduced do
  use Architecture.LogProvider
  def resource_class, do: Resources.BlockProducer
  def filter, do: ["Successfully produced a new block: $breadcrumb"]
end
```

Adding new statistics involves defining providers the statistic consumes, what subset of resources the statistic is applicable to, and a state for the statistic along with how to initialize/update that state. There are two kinds of update functions that are defined for a statistic: one which updates on a regular time interval (just called `update` right now; useful for time based statistics), and another one which handles subscription updates from providers the statistic consumes. Below is an example of a statistic which computes the block production rate of a block producer. Keep in mind that this interface is highly subject to change and will likely be cleaned up some to make it less verbose.

##### NB: some types and attributes were removed from this definition to avoid confusing people who are new to Elixir and focus the conversation on the logic

```elixir
defmodule Statistics.BlockProductionRate do
  use Architecture.Statistic

  def log_providers, do: [LogProviders.BlockProduced]
  def resources(resource_db), do: Resources.Database.all(resource_db, Resources.BlockProducer)

  defmodule State do
    use Class

    defclass(
      start_time: Time.t(),
      elapsed_time: Time.t(),
      last_updated: Time.t(),
      blocks_produced: pos_integer()
    )
  end

  def init(_resource) do
    start_time = Time.utc_now()

    %State{
      start_time: start_time,
      elapsed_time: 0,
      last_updated: start_time,
      blocks_produced: 0
    }
  end

  defp update_time(state) do
    now = :time.now_ns()
    us_since_last_update = Time.diff(now, state.last_updated, :microsecond)
    elapsed_time = Time.add(state.elapsed_time, us_since_last_update, :microsecond)
    %State{state | last_updated: now, elapsed_time: elapsed_time}
  end

  def update(_resource, state), do: update_time(state)

  def handle_log(_resource, state, LogProviders.BlockProduced, _log) do
    %State{state | blocks_produced: state.blocks_produced + 1}
  end
end
```

Validations are added by listing the statistics required to preform a validation, along with a function which will validate the state of these statistics every time they update. Below is an untested (so probably incorrect) example of defining a validation which ensures block producers are producing an expected number of blocks.

```elixir
defmodule Validations.BlockProductionRate do
  use Architecture.Validation

  defp slot_time, do: 3 * 60 * 1000
  defp grace_window(_state), do: 20 * 60 * 1000
  defp acceptable_margin, do: 0.05

  defp win_rate(_), do: raise("TODO")

  # current interface only supports validations computed from a single statistic, for simplicity of PoC
  def statistic, do: Statistics.BlockProductionRate

  def validate(_resource, state) do
    # implication
    if state.elapsed_ns < grace_window(state) do
      :valid
    else
      slots_elapsed = state.elapsed_ns / slot_time()
      slot_production_ratio = state.blocks_produced / slots_elapsed

      # control flow structure like an if-else or a case-switch
      cond do
        slot_production_ratio >= 1 ->
          {:invalid, "wow, something is *really* broken"}

        slot_production_ratio < win_rate(state.stake_ratio) - acceptable_margin() ->
          {:invalid, "not producing enough blocks"}

        slot_production_ratio > win_rate(state.stake_ratio) + acceptable_margin() ->
          {:invalid, "producing more blocks than expected"}

        # default case
        true ->
          :valid
      end
    end
  end
end
```

## Drawbacks
[drawbacks]: #drawbacks

- introducing a new language to the stack adds learning and onboarding overhead
  - (I believe the benefit here outways this cost, but would like to hear other engineer's opinions)
- this design adds a new component to maintain alongside daemon feature development and network releases
  - (still seems better than divorcing validation scripts from protocol development)

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- the primary alternative would be to focus on producing and maintaining a series of validation scripts which run against the network
  - this approach makes more complex validations more difficult
  - implementation would be cheaper for this, but the maintenance would probably be higher
  - determining how to deploy this and test this seems harder (cron jobs with storage volumes to track data across executions? ew)
  - this approach makes it difficult to rely on the automated validation wrt stability against ongoing protocol changes

## Prior art
[prior-art]: #prior-art

- Conner has written a few Python scripts in the `coda-automation` repo which we currently use to generate graphics that we manually validate
  - much of this work will probably be ported into this tool at some point, so this work is still important and provides a basis for some of this services functionality

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- is the protocol team comfortable with maintaining a new service that is not written in OCaml?
- should this service be used as part of the integration testing framework (there is a large overlap in what and how this validation service will monitor the health of the network and what the new integration test framework project intends to achieve)
