# Becoming a Concourse Pilot

This proposal outlines a set of expectations and culture for contributing code
to Concourse.


## Summary

This proposal aims to reduce the reliance on pull request review and shift to a
[wet on wet][bob-ross] style of continuous integration which is accelerated
by trust in automated testing infrastructure and, to some extent, trust among
co-pilots.

As a thought experiment, though not strictly the goal of this proposal, the
hope is that we can get to a point where pull requests can be automatically
merged upon all checks passing.

This proposal outlines a code of ethics for pilots to adhere to in order for
this process to work.

> Rather than holding up pull requests until they're perfect, this process aims
> to encourage continous improvement. With a lower barrier to getting changes in,
> pull requests may be submitted more frequently to fix stylistic or minor issues

> This style should be supported by an automated testing and code analysis
> infrastructure which is the shared responsibility of all co-pilots to maintain
> and continuously strengthen.


## Motivation

Currently, pull request review involves checking for things like...:

* Are all the automated checks successful?
* Does the change fit the product vision?
* Is the change backwards-compatible with existing pipelines?
* Does the code make sense?
* Does the code have sufficient test coverage?

All but one of these tasks involves a human being using their brain. Sometimes
a lot of it. Reviewing code is hard work, and it takes time.

As the Concourse project has grown, pull requests have increased in number and
size. The core team now spends a significant amount of time on code review and
large contributions can take a long time to get merged in.

The more time a pull request takes to be reviewed, the more likely it is to
become stale, resulting in merge conflicts and wasted cycles.

Using our time this way slows down the entire development and release process.
There is less time to implement the roadmap, and forces us to delay changes
until the next release just because there is no time left to review it.

The underlying direction of this proposal is to shift from "review until it's
perfect" to more frequent iterations made collaboratively over time. Rather
than suggesting changes and holding up the merge, trust the PR checks to catch
the important things and make whatever changes you like in a followup PR.


# Proposal

This proposal aims to reduce toil by eliminating the need for a human to
perform these checks. To the furthest application of this idea, pull requests
may be automatically merged as long as all the automated checks are successful.

Pull requests will be merged more aggressively and optimistically. When
something goes wrong, a revert should be made just as aggressively.


## Merge Early, Revert Early

Each pull request runs unit tests, integration tests, and upgrade/downgrade
tests. These must all pass in order for the pull request to be merged.

In addition to all these checks, pull requests are also met by a human
performing code review.

In order to keep up, the core team now dedicates half of each working day to
reviewing pull requests.

# Proposal

* Merge rights (or, "pilot licenses") are granted to individuals at the
  discretion of Concourse core team members.

* Any pilot submitting a pull request is free to merge it at their discretion,
  provided that it passes all the checks.

* Requesting a review is not required, however there should ideally be a
  conversation first for changes which have end-user impact.


--- SCRAP ---


Historically, Concourse as an open source project has erred on the side of
"Cathedral" rather than "Bazaar." This proposal nudges it in the other
direction.

This proposal suggests that we should have more faith in each other and our
tests in order to reduce our reliance on code review and lower the overhead of
getting code merged in.

getting code merged.

This worked well in the early stages of the project, but 
