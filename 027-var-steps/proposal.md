# var steps + local var sources

This proposal introduces two new step types - `load_var` and `get_var` - along
with a new mechanism for builds to use a "local var source" at runtime.

* The `load_var` step can be used to read a value from a file as a var.

* The `get_var` step can be used to fetch a var from a var source and trigger a
  new build when its value changes.

Both steps save the var in the build's "local var source", accessed through the
special var source name `.` - e.g. `((.:some-var))`. (TODO: provide this as an
example for why the valid identifiers RFC prohibits `.` at the start!)

## Motivation

1. The `load_var` step introduces a general mechanism for using a file's
   contents to parameterize later steps. As a result, resource (proto)type
   authors will no longer have to implement `*_file` forms of any of their
   parameters.

1. The `get_var` step introduces more flexible way to trigger and parameterize
   jobs without having to use a resource.

   * A `vault` var source type could be used to trigger a job when a
     credential's value changes, in addition to its normal use for var syntax.

   * A `time` var source type could be used to trigger jobs on independent
     intervals.

   By invoking the var source type with metadata about the job, the var source
   type can base its behavior on the job in question:

   * A `vault` var source can use the team and pipeline name to look for the var
     under scoped paths.

   * A `time` var source could use a hash of the job ID to produce a unique
     interval for each job.

   With the `time` var source producing a unique interval for each job, this
   will eliminate the "stampeding herd" problem caused by having many jobs
   downstream of a single `time` resource.

   This would in turn allow us to un-feature-flag the long-running ["global
   resource history" experiment][global-resources-issue], which allows
   Concourse to optimize equivalent resource definitions into a single history,
   requiring only one `check` interval to keep everything up to date, and
   lowering database disk usage.

## Proposal

### Loading a var's value from a file at runtime

```yaml
plan:
- task: generate-branch-name
  outputs: [branch-name]
- load_var: branch-name
  file: branch-name/name
- put: booklit
  params:
    branch: ((.:branch-name))
    base: master
```

### Triggering on changes from a var source

```yaml
var_sources:
- name: fuzz-tests-interval
  type: time
  config:
    interval: 10m

- name: my-vault
  type: vault
  config:
    url: https://vault.example.com
    ca_cert: # ...
    client_cert: # ...
    client_key: # ...

jobs:
- name: trigger-over-time
  plan:
  - get_var: time
    source: fuzz-tests-interval
    trigger: true

- name: trigger-on-credential-change
  plan:
  # trigger on changes to ((my-vault:cert))
  - get_var: cert
    source: my-vault
    trigger: true
  - put: deployment
    params:
      ca_cert: ((.:cert))

  # trigger on changes to ((my-vault:cert/foo/bar))
  - get_var: cert/foo/bar
    source: my-vault
    trigger: true
  - put: deployment
    params:
      ca_cert: ((.:cert/foo/bar))
```

Build scheduling invokes the var source with a `get` request against an object,
interpreting the response object as the var's values. If the value is different
from the last value used, a new build is triggered. (This comparison can be
based on a hash so we don't have to store sensitive credential values.)

A `time` var source's input object might look something like this:

```json
{
  "var": "time",
  "interval": "10m",
  "team": "some-team",
  "pipeline": "some-pipeline",
  "job": "some-job"
}
```

Note the addition of `team`, `pipeline`, and `job` - this will be automated by
Concourse. (TODO: The format and contents of these values is something we
should probably put more thought into; we may want it to match the
[notifications RFC][notifications-rfc].)

And the respone might look something like this:

```json
{
  "iso8601": "2020-01-18T23:09:00-05:00",
  "unix": 1579406940
}
```

This response would then be loaded into the build's local var source, available
as `((.:time))`.

## Open Questions

* Could this be related to how we approach [concourse/concourse#738](https://github.com/concourse/concourse/issues/783)? :thinking:

## Answered Questions

* n/a

## New Implications

1. A separate RFC could be written so that `get` steps can also provide a local
   var containing the object returned by the resource. This could be used
   instead of writing values to files.

[resources-rfc]: https://github.com/vito/rfcs/blob/resource-prototypes/038-resource-prototypes/proposal.md
[global-resources-issue]: https://github.com/concourse/concourse/issues/2386
[notifications-rfc]: https://github.com/concourse/rfcs/pull/28
