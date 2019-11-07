# Summary

Allow multiple credential managers to be configured, at multiple levels:
globally, per-project, and per-pipeline.

# Motivation

Concourse currently supports configuring a single credential manager the
entire cluster. This is limiting in a number of ways:

## Rigid path lookup schemes

Because auth for the credential manager is configured globally, each credential
manager has to support some form of multi-tenancy so that team A's pipelines
can't read team B's secrets.

The current strategy is to encode team and pipeline names in the paths for the
keys that are looked up, but this has many downsides:

* This makes it impossible to share credentials between teams. Instead the
  credential has to be duplicated under each team's path. This is a shame
  because credential managers like Vault have full-fledged support for ACLs.

* With Vault, this makes it impossible to use any backend except `kv`, because
  all keys live under the same path scheme, and different backends can't be
  mounted under paths managed by other backends. This removes a lot of the
  value of using Vault in the first place.

* Some credential managers, e.g. Azure KeyVault, have very strict requirements
  for key names (`[a-z\-]+`), effectively making scoping conventions impossible
  to enforce as there isn't a safe separator character to use.

## "There can be only one"

Only supporting a single credential manager really limits the possibilities of
using credential managers for specialized use cases.

A core tenent Concourse resources is that their content, i.e. version history
and bits, should be addressable solely by the resource's configuration. That
is, given a resource's `type:` and `source:`, the same version history will be
returned on any Concourse installation, and can therefore be de-duped and
shared across teams within an installation. This means not relying on cluster
state for access control; resource types should entirely trust their `source:`.

This is problematic for resources which make use of IAM roles associated to
their `worker` EC2 instances in order to authenticate, because in this case the
resource's `source:` does not actually include any credentials. As a result, we
cannot safely enable [global
resources](https://concourse-ci.org/global-resources.html#some-resources-should-opt-out)
by default because these resources would share version history without even
vetting their credentials.

A special credential manager could be implemented to acquire credentials via
IAM roles on the `web` EC2 instance and then provide them to the `source:`
configuration via `((vars))`. This way the `source:` configuration is the
source of truth. This is discussed in
[concourse/concourse#3023](https://github.com/concourse/concourse/issues/3023).

However, as there can only be one credential manager configured at a time,
using that single "slot" just for IAM roles is a bit of a waste compared to a
full-fledged credential manager that can be used for many more things.

# Proposal

Key goals:

* Support for multiple credential managers configured at the same time.

* Allow for credential managers to be defined "locally" in a pipeline and, in
  the future, in a [project](https://github.com/concourse/rfcs/pull/32).

* Allow locally-defined credential managers to forego the path restriction.

This proposal introduces a new toplevel configuration to pipelines:
`var_sources`. This name is chosen to build on the existing terminology around
`((vars))` and to directly relate them to one another. Calling them "var
sources" instead of "credential managers" will also let us reason about the
idea more generically so that non-credential-y things can be used as a source
for `((vars))` as well.

`var_sources` looks like this:

```yaml
var_sources:
- name: vault
  type: vault
  config:
    uri: https://vault.example.com
    # ... vault-specific config including auth/etc ...
- # ...
```

Each var source has a `name`. This is used to explicitly reference the source
from `((vars))` syntax so that there is no ambiguity.

The proposed syntax for var lookup, now including a name, is
**`((some-name:some/path.some-field))`**. In this query, `some-name` will
correspond to a name under `var_sources`, and the credential `some/path` will
be fetched, with the `some-field` field read from it.

A var source's `type` names one of the supported credential managers (e.g.
`vault`, `credhub`, `kubernetes`), which is responsible for interpreting
`config`.

## Path lookup rules

Now that credential managers can be configured "locally" we can relax the path
lookup rules as it's no longer necessary to isolate a team's var lookup to a
path that's distinct from other teams.

For ease of use and backwar

  By moving credential manager config to each team we can instead leverage the
  credential manager's access control to determine how credentials are shared
  across teams (e.g. Vault policies).

  By eliminating the path enforcement you can now refer to different secret
  backend mount points.

  By configuring at the team level, each team can point to their own KeyVault
  or configure their own access control.

  By allowing teams to configure multiple credential managers, all credential
  managers can be tried in order when looking up a given credential.

The first step is to extend the team config file set by `fly set-team --config`
to support configuring credential managers. Something like this:

```yaml
roles: # ...

credential_managers:
- type: iam
  config:
    access_key: blahblah
    secret_key: blahblah
- type: vault
  config:
    url: https://vault.example.com:8200
    ca_cert: |
      -----BEGIN CERTIFICATE-----
      ...
    client_token: blahblahbla
```

Then, any time we're resolving a `((var))` the `web` node would resolve the var
using each configured credential manager, in order. Distinct fields can be
accessed like `((foo.bar))`, and nested credential paths can be accessed like
`((foo/bar/baz))`.

In this case, team's Vault auth config would be associated to a policy which
determines which credentials the team can access. This way shared credentials
can be shared without duplicating the credential, and private credentials can
be kept private.

All credential managers would be modified to remove the automatic team/pipeline
variable name scoping. They would instead be looked up starting from the root
level.


# Open Questions

* Is there a need for globally-configured and team-configured credential
  managers to coexist, or can we switch to entirely team-configured (as is the
  initial goal)?

* Concourse will now be responsible for safely storing access to each and every
  credential manager, which increases risk. Is it enough to mitigate this by
  requiring that database encryption be configured?

* Will anyone miss the automatic credential scoping assumptions? Is there value
  in automatically looking under `/(team)/(pipeline)` for `((foo))`?

* Would a default key prefix make sense? e.g. `/concourse`? (Maybe this is just
  up to the discretion of the credential manager?)

* Supporting IAM/STS token acquisition is one of the motivators for this
  proposal, but I think we need a concrete example implementation to really
  understand if this proposal is a good fit. The above example configures an
  access key and secret manually instead of using EC2 IAM role.

* When and how often do we authenticate with each credential manager? If you're
  using Vault with a periodic token, something will have to continuously renew
  the token.

  Will the `web` node have to maintain long-lived clients for accessing each
  configured credential manager across all teams? Is that going to be a
  scalability concern? Is that going to be a security concern? (Can it be
  avoided?)

  Should it detect situations where this is required?

  Should we just not support periodic tokens?

* Should we work credential caching into this proposal?

* How should credential manager authentication errors be surfaced?

* Is there a need for configuring a path prefix (e.g. the default `/concourse`
  for Vault)? I've left that out for now assuming we can just get rid of it.


# Answered Questions


# New Implications
