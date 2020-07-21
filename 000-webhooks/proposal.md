# Summary

Handle and interpret webhooks cluster-wide, figure out which resources they
correspond to, and queue up a `check` for each.


# Motivation

Concourse's primary method of detecting new resource versions is through
periodically running `check`. The default polling frequency for each resource
is 1 minute.

Polling can lead to a lot of pressure on the other end of the `check`
requests. This can lead to rate limiting, or worse, your CI/CD stack DDoSing
your own internal services.

To reduce polling pressure it is typical to configure webhooks, by
configuring a `webhook_token` on a resource and either setting a higher
`check_every` or configuring `--resource-with-webhook-checking-interval`
cluster-wide. This token value is then given to the service, as part of a
per-resource URL.

This is a tedious operation and has severe limitations, as some external
services (e.g. GitHub) have a limit on how many webhooks can be configured on
a repo/org. This means you can only configure webhooks for up to 20 resources
(minus whatever other hooks you have), which is a painful limitation when
there's a common resource used in many pipelines.


# Goals

* Dramatically lower the barrier to entry for webhooks - potentially to the
  extent that an entire cluster can benefit from one person configuring it.

* Reduce Concourse's load on external services by automatically reducing
  check frequency when a resource is checked via a webhook.

* Flexible enough to support configuring a single WebHook URL for an entire
  GitHub organization, rather than having to configure repo-by-repo or
  resource-by-resource.

* Extensible and portable, implemented using a [Prototype][prototypes-rfc]
  interface.


# Proposal

## Key decisions

TRUST THESE PARTS THEREAFTER HRETOFORE QED QUID GOPRO

* Hooks SHOULD NOT be configured "through" a resource - their lifecycle
  has to be independent, to the point where they can be configured
  project-wide.
  * Reasoning: don't want one-hook-per-resource, and want webhooks to work for
    var sources too.

* Hook IDs are scoped within the prototype. i.e., a resource's hook ID will
  only be considered when the same prototype accepts hooks.
  * This solves the problem of hook ID compatibility/ambiguity.
  * This means you'll have one webhook configured per prototype.
  * A given webservice will typically correspond to only a handful of
    prototypes, sometimes only one - so maybe this is OK?
    * e.g. GitHub: `git`, `github`

* A prototype which supports hooks will only handle hooks for things
  (resources, var sources) which use the same prototype.
  * Reasoning: The Hook ID JSON object itself isn't enough to determine compatibility or
    relevance across all resource configs; what if it's just 'url:', and two
    different prototypes interpret it in different ways? (e.g. RSS or
    commits)
  * Arguably they should be checked anyway, but... this doesn't seem guaranteed
    enough. Maybe think about this more either way.
  * In any case, 'type-level' hook propagation seems like a reasonable level of
    granularity. It's not per-resource, but it's also not cluster-wide with no
    namespacing/typing.

* Webhook API endpoint has to be asynchronous and cannot involve worker
  interaction.
  * Slack webhook timeout is 3 seconds.
  * GitHub is 10 seconds.
  * BitBucket is 10 seconds.
  * GitLab doesn't specify an amount, but has similar restrictions.
    * "Your endpoint should send its HTTP response as fast as possible. If you wait too long, GitLab may decide the hook failed and retry it."
  * Container Registry PubSub recommendation is "no more than 30 seconds".
  * Docker Hub timeout is undocumented. (Surprise.)

## Decision points

* Slack events API has a challenge flow. Do we need to allow prototypes to
  respond to events?
  * https://api.slack.com/events/url_verification

* Slack events must be handled in *3 seconds*. Ouch.
  * We might have to just respond 200 OK immediately, but that eliminates the
    possibility for handling the challenge.
  
  * ...eh, this may just be a limitation to note. for Slack you can't just
    point straight at Concourse, you need an app that can handle the challenge.

* GitHub: 10 seconds. But doesn't require challenge, so that's OK.

Prototypes can return a `url` value from the `info` request. This URL will be
exposed in the UI, but more importantly, used to identify which resources to
check from a webhook.

```json
{
  "interface_version": "1.1",
  "icon": "github",

  // XXX: what about different branches?
  // XXX: having to make up a 'bogus' url is weird, especially if we show it in
  // the UI
  // YYY: let's not overload this.
  "url": "https://github.com/vito/booklit"
}
```

ZZZ: maybe hooks should be discovered from a resource's prototype instead,
and the user just generates a URL for it. the `hook` call can return a hook
identifier.

AAA: ...no, this shouldn't stem from a resource if we want org-wide hooks.
prototypes should only specify some sort of hook identifier, and hook
endpoints should be managed by users to prevent abuse of a public endpoint.
this way they can compose together, rather than competing `git` prototypes
both maintaining hook interpretation. (edit: though, let's be honest, that
wouldn't be a huge deal. putting it in the same prototype would probably be a
non-issue.)

BBB: maybe hook identifier should specify event type? how much info should be
parsed from webhook payload? could help to know what we can safely assume.
let's survey various services. maybe `hook` is called with something like
{"event":"push","source":{"url":"https://github.com/vito/booklit","branch":"master"}}

CCC: ...nah, i think handling specific events is a bit too complicated.
better to think of it as 'hey, something happened with this thing, just
re-check everything'. MUCH simpler. global resources should prevent this from
leading to a storm of `check` calls anyway. it's premature optimization.

DDD: 

* org-wide hooks would be dope.
* don't handle specific event types; just let it be a general 'change' indicator and let Concourse figure out what to do
* don't create them from resources; need it to be configurable project-wide (or team-wide)
* they can be implemented in the same prototype, but don't have to be, since it's decoupled from resources
* prototypes implement a `id` call that returns the hook source (identifier) corresponding to the source
  * is this too ambiguous?
  * what if someone does a `git` prototype that supports a repo construct but also supports just 'url: ...' with no branch as a resource?
  * how would it know to include 'branch: master', since the hooks will always be for specifically 'branch: master'?
  * oh. i guess it should just return both objects.
  * or the resource should just make a distinction between them.
  * id should be a canonical identifier, i.e. not just subset of source config
* id is saved for each resource config
  * can be shown in the UI
* prototypes implement a `hook` call that parses a hook payload and returns hook sources
* when hook id is received, each resource config

EEE: ...should this be implemented by the same prototype that implements the
resource/var source/whatever, and only check resources of the same prototype?
  * would that be finnicky with types having versions and stuff?
  * it might not be safe to assume JSON contents are enough to know the things to call, since we can't really know the type.
  * this would resolve compatibility issues too. tbh, processing a hook payload is stupid easy.
  * only downside: can't implement hooker externally. but... who cares? contribute to the main prototype.
    * need to make sure one prototype can handle multiple hook types


TODO: one prototype needs to be able to handle multiple services
The process for this is as follows.

Webhooks are configured in a project:

```yaml
webhooks:
- name: concourse
  type: git
  token: im-a-token

  # FFF: THIS MOSTLY MAKES SENSE, just: how does it know to expect a github payload vs a bitbucket one, or how does it detect the difference?
  config:
    service: github


plan:
- ...
```

The webhook POST URL for the above would be as follows:

```
/api/v1/hooks?project=foo&hook=concourse&token=im-a-token
```

The prototype `hook` would be executed with the request headers and payload:

```json
{
  "object": {
    "headers": {
      "X-GitHub-Event": "push",
    },
    "payload": {
      "ref": "refs/heads/master",
      // ...
    }
  },
  "response_path": "response.json"
}
```

The `hook` message responds with URLs:

```json
{"object":{"url":"https://github.com/concourse/concourse"}}
{"object":{"url":"https://github.com/concourse/concourse/pulls"}}
```

All resource configs with a matching `url` value, returned from the `info`
call, will have a `check` queued.


* Users can benefit from webhooks without even knowing. Either thanks to
  "global resources" or thanks to a Prototype gaining webhooks support and an
  endpoint was already configured.

* Don't worry about being faster than the `check` interval. It's a red herring.
  It should *typically* be faster, and these webhook events most likely won't
  be coming in so quickly that this would be a problem. However we may want to
  do this via a queue just in case there *are* a ton of hook events.

* Must not be too tightly coupled to `check`. Need var sources to be able to
  use hooks too - and that's `list`.

  Maybe `info` call returns a `url` and we use that to identify things to
  `check`, `list`, or whatever needs updating. This URL could also be used as
  a handy link in the UI.

# Proposal

Add an API endpoint for accepting various service webhook requests and
determining resources to `check` based on the payload.

Straw-man endpoint proposal: `/api/v1/hooks/:type`, where `:type` is one of
the supported webhook services.

Support for various services will be built in to Concourse. It will not be
extensible at runtime, but more services can be implemented over time.

While it would certainly be neat to have the set of types be completely
extensible via Prototypes, this would only be worth doing if it can be done
*efficiently*. The overhead of running a container just to interpret the
payload would slightly undermine the goal of being faster than the `check`
interval.

Concourse will have support for interpreting different payloads from
different services. It will be built-in, and not ext
short identifier (e.g. `github`, `bitbucket`).

This should be possible without requiring any modifications to pipeline
configuration. The idea behind this proposal is for webhooks to transparently
accelerate the discovery of resource versions across the cluster.

The service identifier will map to a set of supported webhook receiver types.
The webhook payload will be forwarded to the receiver, which will then return a
URL value identifying the resource which has been updated (e.g.
`https://github.com/vito/booklit`).

This URL will then be associated to resources to `check`. Resource prototypes
would return their webhook URL value via a `hook` message which is given
configuration and must return the following JSON object:

```json
{
  "url": "https://github.com/vito/booklit"
}
```

## Supported 


# Open Questions

## Should the set of services be extensible via Prototypes?

Rather than baking in support for services natively, can we have them somehow
implemented as prototypes?

I think this depends on what we prioritise: reducing the polling burden on
external services, or being faster than the `check` interval?

Do we just bake-in support for certain services? (There are only so many.)

Or do we try to get fancy and leverage Prototypes somehow? (A noble goal, but
who configures this and where? What are the security implications?)

## How is the webhook request authenticated?

We don't want just anyone to be able to send a request here, especially if it
will always result in worker load.

For example, if we used Prototypes to interpret hooks but needed to execute a
Prototype request in order to handle the auth, that would be way too easy to
abuse by sending a ton of requests with bogus auth.

We also need to keep it simple: GitHub only lets you set a URL. It lets you
specify a secret value, but making use of it is GitHub-specific, which would
be problematic given the above scenario.

Given that GitHub doesn't allow you to specify request headers, we'll need to
support accepting a token in the URL via a query param (same as today).

Where does that token come from? Configuring them cluster-wide would be a bit
of a non-starter; the tokens would have to be handed out to people to
actually configure on their repos; spreading cluster-wide tokens is too
risky.

Maybe we need some way of generating a webhook token for a given resource?

```sh
$ fly create-webhook --type github
url: https://ci.example.com/api/v1/hook/github
secret: 23498yfndsfsdf
```

So, maybe the token needs to be created and handled by someone who is already
authorized with the cluster.

## How can we detect that it's OK to reduce the `check` frequency?

When a `check` from a webhook completes, we can record the current time as a
`last_hook_checked` column on the global resource config. When deciding
whether to queue a check, we can queue it in the following conditions:

Concourse can be configured with a default interval for resources configured
with webhooks. This can default to something like `24h`. The intent of
configuring a high interval, rather than disabling the polling entirely, is
to be resilient to missed events.

* if `now() - last_hook_checked` value is >= the configured interval, queue a
  check


# Answered Questions

* 

# New Implications

> What is the impact of this change, outside of the change itself? How might it
> change peoples' workflows today, good or bad?


[prototypes-rfc]: https://github.com/concourse/rfcs/blob/master/037-prototypes/proposal.md