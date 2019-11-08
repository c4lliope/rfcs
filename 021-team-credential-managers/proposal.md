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

A var source's `type` names one of the supported credential managers (e.g.
`vault`, `credhub`, `kubernetes`), which is responsible for interpreting
`config`.

## Var syntax

The `((var))` syntax will be extended to support querying a specific
`var_source` by name.

The full `((var))` syntax will be
`((VAR_SOURCE_NAME:SECRET_PATH.SECRET_FIELD))`.

The `VAR_SOURCE_NAME` segment specifies which named entry under `var_sources`
to use for the credential lookup. If omitted (along with the `:`), the globally
configured credential manager is used.

The `SECRET_PATH` specifies the secret to be fetched. This can either be a
single word (`foo`) or a path (`foo/bar` or `/foo/bar`), depending on what
lookup schemes are supported by the credential manager. For example, Vault and
CredHub have path semantics whereas Kubernetes and Azure KeyVault only support
simple names

If `SECRET_FIELD` is omitted, the credential manager implementation may opt to
choose a default field. For example, the Vault implementation will read the
`value` field if present. This is useful for simple single-value secrets.

If `SECRET_PATH` begins with a slash (`/`), the exact specified path will be
fetched.

If `SECRET_PATH` does not begin with a slash (`/`), the secret path may be
queried under various paths determined by the var source and its configuration.

## Path lookup rules

Now that credential managers can be configured "locally" we can relax the path
lookup rules as it's no longer necessary to isolate a team's var lookup to a
path that's distinct from other teams.

This means that credentials can be shared between teams, and credential manager
specific settings such as ACLs may be utilized to securely share access to
common credentials.

Credential managers may still choose to have default path lookup schemes for
convenience. This RFC makes no judgment call on this because the utility of
this will vary between credential managers.


## Maintaining auth


# Open Questions

* When and how often do we authenticate with each credential manager? If you're
  using Vault with a periodic token, something will have to continuously renew
  the token.

  Will the `web` node have to maintain long-lived clients for accessing each
  configured credential manager across all teams? Is that going to be a
  scalability concern? Is that going to be a security concern? (Can it be
  avoided?)

  Should it detect situations where this is required?

  Should we just not support periodic tokens?

# Answered Questions

# New Implications
