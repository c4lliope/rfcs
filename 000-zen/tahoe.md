# Ideas

## Web UI, CLI & API

Other CI systems already have a good idea of how this should be done. Jenkins
has excellent support for configuration changes and the Travis console output is
pretty much incredible. Something that they both lack is performance. Taking
more than quarter of a second to load a page is unacceptable an infuriating.

A good command line interface has been missing from all CI systems I've used. It
should be possible to see recent builds, re-run builds, and download artefacts
from the command line without opening a web-browser.

## Minimal Static Build Configuration

Having large amounts of untested Bash script in that little script box in
Jenkins is an anti-pattern. Travis gets this right. Your build scripts should
live inside your repository and be versioned along with your code.

## Distributed by Default

Builds only run on worker nodes rather than the director node. Having this
constraint from the start ensures that distribution is a first class citizen and
doesn't feel bolted on. I'd love for a project end-goal to be able to spin up a
hundred slaves and for the system to be just as simple to use as if there were
only one.

## BOSH Deployable

This is more of a personal preference. The system should be deployed with
[BOSH][1] because I don't want to have to care about and maintain some Chef or
Puppet scripts and I agree with the BOSH approach to distributed systems.

[1]: https://github.com/cloudfoundry/bosh

## Builds inside Docker/Warden Containers

To ensure that a build is in complete isolation we should perform as many
builds as possible inside some form of containers. Of course not all hosts or
builds will be able to or want to support this so it can be turned off on a
build-by-build basis.

## Easy build Matrices

Similar to Travis.

## Slaves on any Host OS

There should be a simple interface to implement in order to register oneself as
an eligible build slave. This way if you have builds that you would like to run
on Windows servers - no problem.

## Green Artefacts promoted to a Blobstore

There should be a built in mechanism for storing good artefacts in a blobstore.
These can then be reused easily in other builds, downloaded through the CLI, or
posted publicly.

## Easily Repeatable Builds

By running an old build with the same parameters in a container it should be
possible to have an exact replica of any build.

## Flaky Test Detection

This is more of a fantasy but it would be awesome if we could detect flaky
tests.

## Resumable Build Flows

If a flaky build in the middle of a flow fails then we should be able to re-run
it and continue from where we left off.

## Dependency Graphs

You made a change to a shared library? Let's rebuild all of the things that
depend on it to check that those aren't broken either.

## Public Status Page

You may want to keep your configuration private but the status of builds should
be able to be made public so that others can see how their contributions are
progressing through the pipeline. (This may be a feature that applies only to
companies such as Cloud Foundry).

## Pull Request Testing

Test GitHub pull requests before you merge them and even merge them
automatically for you if they pass (but only from certain people!).

## Built in Build Status Monitor

Put this on a radiator and see all of your builds in glorious red and green.
