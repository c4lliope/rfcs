# The Zen of Concourse

## Noble Goals

Reproducible + Ephemeral = Concourse

* Concourse lets you sleep at night by preventing you from taking shortcuts during the day.
  * CI and automation has historically been a bit of a cludge.

* Concourse is designed to be a CI system that lets you sleep easy.
  * It does this by making it hard to take shortcuts that will blow up in your face,
  * and by making it easy to recover from a disastrous CI meltdown.

* The result of using Concourse should be a declarative configuration which acts as a "source of truth" describing your project's entire workflow.
  * When your Concourse cluster fails, this configuration should be transferrable to a new cluster.
  * When a better Concourse implementation arrives, you should be able to switch with minimal overhead.
  * When a nuclear war breaks out and all software is lost, your configuration should still be able to describe how to ship your product.
  * When aliens arrive, once they learn YAML and POSIX they should be able to take over as maintainers.

* If a Concourse cluster fails, recovery should be trivial.
  * Pipelines should come back, run from beginning to end, and achieve the same result as if Concourse never disappeared.

* If a build is re-run, it should always have the same result.
  * i.e. be explicit about your dependencies, and don't rely on ephemeral state

* When a new technology replaces Kubernetes, your pipelines shouldn't have to change.
  * i.e., a pipeline should work the same on a Kubernetes Concourse, a Garden Concourse, a Nomad Concourse, etc.
  * Bet on POSIX. It's the only thing that's safe.
  * Don't even assume filesystem layouts. (Tasks are scoped to a $PWD.)

* Concourse's concepts (build plans, pipelines, ...) are the API.
  * Something better than Concourse could be written to drive the same workflows.
  * Pipelines should not depend on implementation-specific things like the cluster API server.


* Concourse itself is not an "input." It is the dot connector, not a dot.
  * Concourse drives the connection between two sources of truth. It is not itself a source of input parameters.
    * Builds cannot be parameterized.
    * Tasks are not given information about where they're running.
  * Concourse is a reactive workflow system, not an interactive workflow system.
  * caveat: worker state is still a little fiddly, e.g. deploying workers with tags and tying tasks to them.

* Artifacts are forever.
  * Managed and persisted external to Concourse.
  * e.g. `get` will always yield the same bits
* Concourse is ephemeral.
  * Outcomes:
    * Make your pipelines portable.
    * Don't tie artifacts to Concourse's ephemeral state.


* Think continuously. If it's worth doing, it's worth automating.
  * It's possible to have too much automation, but it's easier to have too little automation.
  * Having too much automation is the better problem to have.

* Think explicitly. All variables and dependencies should be accounted for.
  * interesting note: time, random seeds are not accounted for atm

* Think precisely. Avoid overloading or overspecifying information. Look for the core meaning of what you're trying to do.
  * "I want to use the build number to version my artifacts" is stating more than you intend:
    * "When I configure my pipeline fresh, I want my artifact versions to start over at 1."
    * This is almost never what you want.
  * "I want to test against Postgres 9.5 and Postgres 12" is overspecifying when really the following statements are the underlying need:
    * "I have a minimum supported version, which may change in the future, but is currently set to 9.5"
    * "I want to test against the latest version of Postgres, and we can keep rolling forward in order to notice breakage early"

* Say "what", not "how".
  * Achieve consistency and portability through declarative configuration.
  * "How" changes with technology fads. "What" is forever.

* Value idempotency.
* Value consistency, eventual or not.
* Value safety.
  * If a part of Concourse fails or disappears and has to be recreated, your product should not be impacted.
    * ex. recovering a pipeline and having version numbers reset to 1 when build IDs reset

* Value short feedback loops.



