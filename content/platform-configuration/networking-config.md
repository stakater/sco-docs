# NetworkingConfig

Turn on network isolation and egress rules for platform namespaces, and verify or roll them back.

Sam, a platform administrator, has to show that platform components accept traffic only from where they need it. She turns on isolation for one component first, checks that it still works, and then widens it.

!!! note "New in the next release"
    `NetworkingConfig` ships with the [next release](../release-notes/next-release.md), which is not released yet.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `config.platform.stakater.com` |
| **Version** | `v1alpha1` |
| **Kind** | `NetworkingConfig` |
| **Scope** | Cluster |
| **Name** | `cluster` (the only name accepted) |
| **Roles** | `platform-config-networking-admin`, `platform-config-networking-view`. See [Access](overview.md#access) |
| **Schema** | [`networkingconfig.schema.json`](networkingconfig.schema.json) (JSON Schema draft-07) |
| **Example** | [`networkingconfig.example.yaml`](networkingconfig.example.yaml) (every field, with its description) |

`spec.parameters` has two independent sections:

| Section | What it controls |
|---------|------------------|
| `isolation` | Incoming traffic to platform namespaces, with Kubernetes `NetworkPolicy` objects |
| `egress` | Traffic leaving the cluster from platform namespaces, with an OVN-Kubernetes `EgressFirewall` per namespace |

## How a Namespace's Setting Is Resolved

In each section, `enabled` can be set at three levels. For each platform namespace, the most specific level that is set wins:

1. `namespaces.<namespace>.enabled`
1. `stacks.<stack>.enabled`, for the stack the namespace belongs to
1. `enabled`, platform-wide
1. none set: the release default, which is **off** for both sections in this release

Everything else is applied only when you set it: a rule you do not mention keeps its built-in setting.

### Stacks

| Stack | Platform components |
|-------|---------------------|
| `backup` | Backup and restore |
| `bootstrap` | The GitOps components that install the platform |
| `cicd` | Pipelines, registry and code quality |
| `gitops` | GitOps configuration |
| `identity` | Single sign-on and access management |
| `networking` | Ingress, load balancing and DNS |
| `observability` | Logging, monitoring and alerting |
| `platform` | Core platform components |
| `security` | Secrets, certificates and policy |
| `storage` | Storage |

### Supported Namespaces in This Release

| Namespace | Component | Stack | Built-in settings |
|-----------|-----------|-------|-------------------|
| `stakater-forecastle` | Forecastle | `platform` | `fromRouter: true`, `fromHostNetwork: false`, no extra ingress rules, no egress rules |

Settings for any other namespace, or for stacks without a supported namespace, change nothing yet. Namespaces you name that match no supported namespace are listed in `status.isolation.unmatched.namespaces` and `status.egress.unmatched.namespaces`.

## What Isolation Creates

When isolation is on for a namespace, the namespace gets these `NetworkPolicy` objects, all for ingress only:

| NetworkPolicy | Allows |
|---------------|--------|
| `default-deny-ingress` | Nothing: denies all incoming traffic not allowed below |
| `allow-same-namespace` | Pods in the same namespace |
| `allow-from-monitoring` | Platform monitoring (metrics scraping) |
| `allow-from-router` | The cluster's ingress routers. Only with `fromRouter: true`; needed for a component served through a Route |
| `allow-from-host-network` | The host network. Only with `fromHostNetwork: true`; needed for a component that serves admission webhooks or aggregated APIs |
| one per entry in `ingress` | The sources in that entry, to the pods and ports in it |

The baseline policies carry the label `stakater.com/network-policy: baseline`.

## What Egress Rules Create

When egress rules are on for a namespace, it gets one `EgressFirewall` named `default` with the rules you set. Rules are evaluated in `priority` order, lowest first, and the first match wins. **Nothing is denied unless you add a `Deny` rule.** To allow only some destinations, add `Allow` rules and end with a `Deny` rule for `0.0.0.0/0` at a higher `priority` number.

Egress rules apply to traffic that leaves the cluster. They do not restrict traffic between pods in the cluster.

## Prerequisites

- The platform at the [next release](../release-notes/next-release.md) or later
- `kubectl` access to the cluster that runs the platform, as cluster administrator or with `platform-config-networking-admin`
- Your platform's GitOps repository, where you commit the object

## Step 1: Turn On Isolation for Forecastle

Create `networkingconfig.yaml` in your GitOps repository:

```yaml
apiVersion: config.platform.stakater.com/v1alpha1
kind: NetworkingConfig
metadata:
  name: cluster
spec:
  parameters:
    isolation:
      namespaces:
        stakater-forecastle:
          enabled: true
```

Forecastle is served through a Route, so its built-in `fromRouter: true` already lets the router in. You do not need to repeat it.

Optionally validate the file against the schema in CI, for example with [`kubeconform`](https://github.com/yannh/kubeconform):

```bash
kubeconform -strict -schema-location 'networkingconfig.schema.json' networkingconfig.yaml
```

The schema checks structure and allowed values. The API server also checks the rules that the schema cannot express, such as name formats and the shape of a traffic source.

Commit, review and merge the change. Your GitOps tool applies it.

## Step 2: Verify

Check the status. Forecastle is listed with `enabled: true` and `source: namespace`, and `unmatched.namespaces` is empty:

```bash
kubectl get networkingconfig cluster -o jsonpath='{.status.isolation}' | jq
```

```json
{
  "addons": [
    {
      "name": "forecastle",
      "namespace": "stakater-forecastle",
      "stack": "platform",
      "enabled": true,
      "source": "namespace"
    }
  ],
  "unmatched": {
    "namespaces": []
  }
}
```

The list can also hold other platform components, with `source: release-default`. `source` is the level that set the value: `namespace`, `stack`, `platform`, or `release-default` when nothing is set (then `enabled` is absent).

Check that the policies exist. It can take a few minutes for the platform to apply them:

```bash
kubectl get networkpolicy -n stakater-forecastle
```

```text
NAME                     POD-SELECTOR   AGE
allow-from-monitoring    <none>         1m
allow-from-router        <none>         1m
allow-same-namespace     <none>         1m
default-deny-ingress     <none>         1m
```

Check that Forecastle still answers through its Route. A redirect to sign-in (`302`) or `200` is a pass; a timeout is a fail:

```bash
HOST=$(kubectl get route -n stakater-forecastle -o jsonpath='{.items[0].spec.host}')
curl -s -o /dev/null -w '%{http_code}\n' "https://$HOST"
```

## Step 3: Roll Back

Pick the smallest change that fixes the problem, and commit it like any other change:

| To | Change |
|----|--------|
| Turn isolation off for Forecastle only | Set `isolation.namespaces.stakater-forecastle.enabled: false` |
| Return Forecastle to the release default (off in this release) | Remove the `stakater-forecastle` entry |
| Remove everything `NetworkingConfig` set | Delete the `NetworkingConfig` named `cluster` from your GitOps repository |

Then verify: `kubectl get networkpolicy -n stakater-forecastle` lists no policies with the label `stakater.com/network-policy: baseline`, and the Route answers again. If the policies remain, sync the Forecastle application in your GitOps tool with pruning enabled.

## Turn On Isolation More Widely

When one namespace works, widen the scope with a stack or the platform-wide switch, and exclude what must stay open:

```yaml
spec:
  parameters:
    isolation:
      enabled: true              # every supported namespace
      stacks:
        security:
          enabled: false         # except the security stack
      namespaces:
        stakater-forecastle:
          ingress:
            from-corp-monitoring:  # an extra source for this namespace
              from:
                - ipBlock:
                    cidr: 10.20.0.0/16
              ports:
                - port: 8080
                  protocol: TCP
```

A rule in `ingress` that uses the name of a built-in rule changes that rule. `enabled: false` alone switches a built-in rule off.

## Add Egress Rules

Allow Forecastle to reach one registry and nothing else outside the cluster:

```yaml
spec:
  parameters:
    egress:
      namespaces:
        stakater-forecastle:
          enabled: true
          rules:
            allow-quay:
              priority: 100
              type: Allow
              to:
                dnsName: quay.io
              ports:
                - protocol: TCP
                  port: 443
            deny-everything-else:
              priority: 5000
              type: Deny
              to:
                cidrSelector: 0.0.0.0/0
```

Verify:

```bash
kubectl get networkingconfig cluster -o jsonpath='{.status.egress}' | jq
kubectl get egressfirewall default -n stakater-forecastle -o yaml
```

Roll back by setting `egress.namespaces.stakater-forecastle.enabled: false`, or by removing the entry.

## Precedence

`NetworkingConfig` overrides the defaults of the platform release. An override `EnvironmentConfig` for the same component (see [Platform Configuration](../installation/configuration.md)) still overrides `NetworkingConfig`. If a setting does not take effect, check for such an override first.

## Reference

Every parameter, the value that applies when it is unset, and the values it accepts.

| Parameter | Type | When unset | Allowed values | Description |
| --- | --- | --- | --- | --- |
| `spec.parameters` | object | - | - | Networking settings for the platform. |
| `spec.parameters.egress` | object | - | - | Rules for traffic that leaves the cluster from platform namespaces. The rules of a namespace are evaluated in priority order and the first match wins. Nothing is denied unless a Deny rule is configured. Egress rules are independent of network isolation. |
| `spec.parameters.egress.enabled` | boolean | Each namespace keeps the default of the platform release, which is off. | - | Turns platform-managed egress rules on or off for every platform namespace that supports them. An entry under stacks or namespaces overrides this value for the namespaces it covers. When unset, each namespace keeps the default of the platform release, which is off. |
| `spec.parameters.egress.namespaces` | map of object | - | at most 64 entries; namespace names must be lowercase DNS labels | Egress rules for individual platform namespaces, keyed by namespace name. Only namespaces that belong to the platform itself are configured here. A namespace entry overrides enabled and the matching stacks entry for that namespace. Namespace names that match no platform namespace with egress rules are reported in `status.egress.unmatched.namespaces`. |
| `spec.parameters.egress.namespaces.<name>.enabled` | boolean | The namespace follows its stacks entry, or enabled when the stack has no entry. | - | Turns egress rules on or off for this namespace. When unset, the namespace follows its stacks entry, or enabled when the stack has no entry. |
| `spec.parameters.egress.namespaces.<name>.rules` | map of object | - | at most 64 entries; rule names must be lowercase DNS labels; to is required unless the rule sets enabled to false | Egress rules of this namespace, keyed by rule name. A rule name is a lowercase DNS label. A rule that uses the name of a built-in rule changes that rule; any other name adds a rule. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.enabled` | boolean | A new rule is on and a built-in rule of the same name keeps its setting. | - | Turns this rule on or off. When unset, a new rule is on and a built-in rule of the same name keeps its setting. Set false, without to, to switch off a built-in rule. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.ports` | list of object | The rule matches every port. | at most 32 items | Destination ports the rule matches. When unset, the rule matches every port. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.ports[].port` | integer | required | minimum 1; maximum 65535 | Destination port number. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.ports[].protocol` | string | required | `TCP`, `UDP`, `SCTP` | Protocol of the traffic: TCP, UDP or SCTP. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.priority` | integer | A new rule gets 1000 and a built-in rule of the same name keeps its position. | minimum 0 | Position of the rule in the evaluation order. Rules with a lower number are evaluated first, rules with the same number in name order. When unset, a new rule gets 1000 and a built-in rule of the same name keeps its position. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.to` | object | - | set exactly one of `dnsName`, `cidrSelector` or `nodeSelector` | Destination the rule matches: exactly one of `dnsName`, `cidrSelector` or `nodeSelector`. Required unless the rule sets enabled to false. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.to.cidrSelector` | string | The rule matches by `dnsName` or `nodeSelector`. | at most 64 characters; matches `^(([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]\|[12][0-9]\|3[0-2])\|[0-9A-Fa-f:]*:[0-9A-Fa-f:.]*/([0-9]\|[1-9][0-9]\|1[01][0-9]\|12[0-8]))$`; `cidrSelector` must be a CIDR | Destination address range in CIDR notation, for example 10.20.0.0/16. When unset, the rule matches by `dnsName` or `nodeSelector`. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.to.dnsName` | string | The rule matches by `cidrSelector` or `nodeSelector`. | at most 253 characters; matches `^(\*\.)?([A-Za-z0-9-]+\.)*[A-Za-z0-9-]+\.?$` | DNS name of the destination, for example `quay.io`. A leading *. matches every subdomain. When unset, the rule matches by `cidrSelector` or `nodeSelector`. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.to.nodeSelector` | object | - | - | Selects cluster nodes as the destination, by label. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.to.nodeSelector.matchExpressions` | list of object | - | at most 16 items | Label requirements a node must meet. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.to.nodeSelector.matchExpressions[].key` | string | required | - | Label key the requirement applies to. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.to.nodeSelector.matchExpressions[].operator` | string | required | `In`, `NotIn`, `Exists`, `DoesNotExist` | How the label is compared with values: In, NotIn, Exists or DoesNotExist. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.to.nodeSelector.matchExpressions[].values` | list of string | The requirement carries no values, as Exists and DoesNotExist expect. | at most 32 items | Label values for In and NotIn. When unset, the requirement carries no values, as Exists and DoesNotExist expect. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.to.nodeSelector.matchLabels` | map of string | No label is required. | - | Labels a node must carry, as key and value pairs. When unset, no label is required. |
| `spec.parameters.egress.namespaces.<name>.rules.<name>.type` | string | A new rule allows traffic and a built-in rule of the same name keeps its type. | `Allow`, `Deny` | Whether matching traffic is allowed or denied: Allow or Deny. When unset, a new rule allows traffic and a built-in rule of the same name keeps its type. |
| `spec.parameters.egress.stacks` | object | - | - | Egress rule switches for groups of platform components, one per stack. A stack entry overrides enabled for every platform namespace of that stack. When a stack has no entry, its namespaces follow enabled. |
| `spec.parameters.egress.stacks.backup` | object | - | - | Egress rule switch for the backup and restore components. |
| `spec.parameters.egress.stacks.backup.enabled` | boolean | required | - | Turns platform-managed egress rules on or off for the platform namespaces of the backup stack. |
| `spec.parameters.egress.stacks.bootstrap` | object | - | - | Egress rule switch for the GitOps components that install the platform. |
| `spec.parameters.egress.stacks.bootstrap.enabled` | boolean | required | - | Turns platform-managed egress rules on or off for the platform namespaces of the bootstrap stack. |
| `spec.parameters.egress.stacks.cicd` | object | - | - | Egress rule switch for the pipeline, registry and code quality components. |
| `spec.parameters.egress.stacks.cicd.enabled` | boolean | required | - | Turns platform-managed egress rules on or off for the platform namespaces of the `cicd` stack. |
| `spec.parameters.egress.stacks.gitops` | object | - | - | Egress rule switch for the GitOps configuration components. |
| `spec.parameters.egress.stacks.gitops.enabled` | boolean | required | - | Turns platform-managed egress rules on or off for the platform namespaces of the `gitops` stack. |
| `spec.parameters.egress.stacks.identity` | object | - | - | Egress rule switch for the single sign-on and access management components. |
| `spec.parameters.egress.stacks.identity.enabled` | boolean | required | - | Turns platform-managed egress rules on or off for the platform namespaces of the identity stack. |
| `spec.parameters.egress.stacks.networking` | object | - | - | Egress rule switch for the ingress, load balancing and DNS components. |
| `spec.parameters.egress.stacks.networking.enabled` | boolean | required | - | Turns platform-managed egress rules on or off for the platform namespaces of the networking stack. |
| `spec.parameters.egress.stacks.observability` | object | - | - | Egress rule switch for the logging, monitoring and alerting components. |
| `spec.parameters.egress.stacks.observability.enabled` | boolean | required | - | Turns platform-managed egress rules on or off for the platform namespaces of the observability stack. |
| `spec.parameters.egress.stacks.platform` | object | - | - | Egress rule switch for the core platform components. |
| `spec.parameters.egress.stacks.platform.enabled` | boolean | required | - | Turns platform-managed egress rules on or off for the platform namespaces of the platform stack. |
| `spec.parameters.egress.stacks.security` | object | - | - | Egress rule switch for the secret, certificate and policy components. |
| `spec.parameters.egress.stacks.security.enabled` | boolean | required | - | Turns platform-managed egress rules on or off for the platform namespaces of the security stack. |
| `spec.parameters.egress.stacks.storage` | object | - | - | Egress rule switch for the storage components. |
| `spec.parameters.egress.stacks.storage.enabled` | boolean | required | - | Turns platform-managed egress rules on or off for the platform namespaces of the storage stack. |
| `spec.parameters.isolation` | object | - | - | Network isolation of platform namespaces. An isolated namespace accepts traffic only from its own workloads, from platform monitoring, and from the sources allowed for that namespace. |
| `spec.parameters.isolation.enabled` | boolean | Each namespace keeps the default of the platform release, which is off. | - | Turns network isolation on or off for every platform namespace that supports it. An entry under stacks or namespaces overrides this value for the namespaces it covers. When unset, each namespace keeps the default of the platform release, which is off. |
| `spec.parameters.isolation.namespaces` | map of object | - | at most 64 entries; namespace names must be lowercase DNS labels | Network isolation settings for individual platform namespaces, keyed by namespace name. Only namespaces that belong to the platform itself are configured here. A namespace entry overrides enabled and the matching stacks entry for that namespace. Namespace names that match no isolated platform namespace are reported in `status.isolation.unmatched.namespaces`. |
| `spec.parameters.isolation.namespaces.<name>.enabled` | boolean | The namespace follows its stacks entry, or enabled when the stack has no entry. | - | Turns network isolation on or off for this namespace. When unset, the namespace follows its stacks entry, or enabled when the stack has no entry. |
| `spec.parameters.isolation.namespaces.<name>.fromHostNetwork` | boolean | The namespace keeps its built-in setting. | - | Allows traffic from the cluster's host network into this namespace. Set true for a namespace that serves admission webhooks or aggregated APIs, which the Kubernetes API server calls from the host network. When unset, the namespace keeps its built-in setting. |
| `spec.parameters.isolation.namespaces.<name>.fromRouter` | boolean | The namespace keeps its built-in setting. | - | Allows traffic from the cluster's ingress routers into this namespace. Set true for a namespace that serves Routes. When unset, the namespace keeps its built-in setting. |
| `spec.parameters.isolation.namespaces.<name>.ingress` | map of object | - | at most 16 entries; rule names must be lowercase DNS labels; from is required unless the rule sets enabled to false | Additional traffic allowed into this namespace, keyed by rule name. A rule name is a lowercase DNS label. A rule that uses the name of a built-in rule changes that rule; any other name adds a rule. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.enabled` | boolean | A new rule is on and a built-in rule of the same name keeps its setting. | - | Turns this rule on or off. When unset, a new rule is on and a built-in rule of the same name keeps its setting. Set false, without from, to switch off a built-in rule. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from` | list of object | - | at least 1 items; at most 16 items; set `ipBlock`, `namespaceSelector` or `podSelector`; `ipBlock` cannot be combined with `namespaceSelector` or `podSelector` | Sources allowed to connect, at least one. Traffic is allowed when it matches any entry. Required unless the rule sets enabled to false. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].ipBlock` | object | - | - | An IP address range outside the cluster's pod network. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].ipBlock.cidr` | string | required | at most 64 characters; matches `^(([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]\|[12][0-9]\|3[0-2])\|[0-9A-Fa-f:]*:[0-9A-Fa-f:.]*/([0-9]\|[1-9][0-9]\|1[01][0-9]\|12[0-8]))$`; `cidr` must be a CIDR | Address range in CIDR notation, for example 10.20.0.0/16. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].ipBlock.except` | list of string | The whole `cidr` range is allowed. | at most 8 items; except entries must be CIDRs | Address ranges inside `cidr` that are not allowed, in CIDR notation. When unset, the whole `cidr` range is allowed. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].namespaceSelector` | object | - | - | Selects source namespaces by label. An empty selector selects every namespace. Without `podSelector`, every pod in the selected namespaces is allowed. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].namespaceSelector.matchExpressions` | list of object | - | at most 16 items | Label requirements a namespace must meet. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].namespaceSelector.matchExpressions[].key` | string | required | - | Label key the requirement applies to. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].namespaceSelector.matchExpressions[].operator` | string | required | `In`, `NotIn`, `Exists`, `DoesNotExist` | How the label is compared with values: In, NotIn, Exists or DoesNotExist. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].namespaceSelector.matchExpressions[].values` | list of string | The requirement carries no values, as Exists and DoesNotExist expect. | at most 32 items | Label values for In and NotIn. When unset, the requirement carries no values, as Exists and DoesNotExist expect. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].namespaceSelector.matchLabels` | map of string | No label is required. | - | Labels a namespace must carry, as key and value pairs. When unset, no label is required. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].podSelector` | object | - | - | Selects source pods by label. With `namespaceSelector`, pods are matched in the selected namespaces; without it, in this namespace. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].podSelector.matchExpressions` | list of object | - | at most 16 items | Label requirements a pod must meet. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].podSelector.matchExpressions[].key` | string | required | - | Label key the requirement applies to. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].podSelector.matchExpressions[].operator` | string | required | `In`, `NotIn`, `Exists`, `DoesNotExist` | How the label is compared with values: In, NotIn, Exists or DoesNotExist. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].podSelector.matchExpressions[].values` | list of string | The requirement carries no values, as Exists and DoesNotExist expect. | at most 32 items | Label values for In and NotIn. When unset, the requirement carries no values, as Exists and DoesNotExist expect. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.from[].podSelector.matchLabels` | map of string | No label is required. | - | Labels a pod must carry, as key and value pairs. When unset, no label is required. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.podSelector` | object | - | - | Selects the pods in this namespace that the rule applies to. An empty selector, the default, selects every pod in the namespace. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.podSelector.matchExpressions` | list of object | - | at most 16 items | Label requirements a pod must meet. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.podSelector.matchExpressions[].key` | string | required | - | Label key the requirement applies to. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.podSelector.matchExpressions[].operator` | string | required | `In`, `NotIn`, `Exists`, `DoesNotExist` | How the label is compared with values: In, NotIn, Exists or DoesNotExist. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.podSelector.matchExpressions[].values` | list of string | The requirement carries no values, as Exists and DoesNotExist expect. | at most 32 items | Label values for In and NotIn. When unset, the requirement carries no values, as Exists and DoesNotExist expect. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.podSelector.matchLabels` | map of string | No label is required. | - | Labels a pod must carry, as key and value pairs. When unset, no label is required. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.ports` | list of object | Every port is allowed. | at most 32 items | Ports the sources may connect to. When unset, every port is allowed. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.ports[].endPort` | integer | Only port is allowed. | minimum 1; maximum 65535 | Last port of a range that starts at port. Requires a numeric port. When unset, only port is allowed. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.ports[].port` | integer or string | Every port of the protocol is allowed. | - | Port number, or the name of a container port. When unset, every port of the protocol is allowed. |
| `spec.parameters.isolation.namespaces.<name>.ingress.<name>.ports[].protocol` | string | TCP applies. | `TCP`, `UDP`, `SCTP` | Protocol of the traffic: TCP, UDP or SCTP. When unset, TCP applies. |
| `spec.parameters.isolation.stacks` | object | - | - | Network isolation switches for groups of platform components, one per stack. A stack entry overrides enabled for every platform namespace of that stack. When a stack has no entry, its namespaces follow enabled. |
| `spec.parameters.isolation.stacks.backup` | object | - | - | Network isolation switch for the backup and restore components. |
| `spec.parameters.isolation.stacks.backup.enabled` | boolean | required | - | Turns network isolation on or off for the platform namespaces of the backup stack. |
| `spec.parameters.isolation.stacks.bootstrap` | object | - | - | Network isolation switch for the GitOps components that install the platform. |
| `spec.parameters.isolation.stacks.bootstrap.enabled` | boolean | required | - | Turns network isolation on or off for the platform namespaces of the bootstrap stack. |
| `spec.parameters.isolation.stacks.cicd` | object | - | - | Network isolation switch for the pipeline, registry and code quality components. |
| `spec.parameters.isolation.stacks.cicd.enabled` | boolean | required | - | Turns network isolation on or off for the platform namespaces of the `cicd` stack. |
| `spec.parameters.isolation.stacks.gitops` | object | - | - | Network isolation switch for the GitOps configuration components. |
| `spec.parameters.isolation.stacks.gitops.enabled` | boolean | required | - | Turns network isolation on or off for the platform namespaces of the `gitops` stack. |
| `spec.parameters.isolation.stacks.identity` | object | - | - | Network isolation switch for the single sign-on and access management components. |
| `spec.parameters.isolation.stacks.identity.enabled` | boolean | required | - | Turns network isolation on or off for the platform namespaces of the identity stack. |
| `spec.parameters.isolation.stacks.networking` | object | - | - | Network isolation switch for the ingress, load balancing and DNS components. |
| `spec.parameters.isolation.stacks.networking.enabled` | boolean | required | - | Turns network isolation on or off for the platform namespaces of the networking stack. |
| `spec.parameters.isolation.stacks.observability` | object | - | - | Network isolation switch for the logging, monitoring and alerting components. |
| `spec.parameters.isolation.stacks.observability.enabled` | boolean | required | - | Turns network isolation on or off for the platform namespaces of the observability stack. |
| `spec.parameters.isolation.stacks.platform` | object | - | - | Network isolation switch for the core platform components. |
| `spec.parameters.isolation.stacks.platform.enabled` | boolean | required | - | Turns network isolation on or off for the platform namespaces of the platform stack. |
| `spec.parameters.isolation.stacks.security` | object | - | - | Network isolation switch for the secret, certificate and policy components. |
| `spec.parameters.isolation.stacks.security.enabled` | boolean | required | - | Turns network isolation on or off for the platform namespaces of the security stack. |
| `spec.parameters.isolation.stacks.storage` | object | - | - | Network isolation switch for the storage components. |
| `spec.parameters.isolation.stacks.storage.enabled` | boolean | required | - | Turns network isolation on or off for the platform namespaces of the storage stack. |

## Full Example

Every parameter set, each with its description. Download: [`networkingconfig.example.yaml`](networkingconfig.example.yaml).

```yaml
# NetworkingConfig holds the platform's networking settings. A cluster has one
# NetworkingConfig, named cluster.
apiVersion: config.platform.stakater.com/v1alpha1
kind: NetworkingConfig
metadata:
  name: cluster
spec:
  # Networking settings for the platform.
  parameters:
    # Rules for traffic that leaves the cluster from platform namespaces. The rules of a
    # namespace are evaluated in priority order and the first match wins. Nothing is
    # denied unless a Deny rule is configured. Egress rules are independent of network
    # isolation.
    egress:
      # Turns platform-managed egress rules on or off for every platform namespace that
      # supports them. An entry under stacks or namespaces overrides this value for the
      # namespaces it covers. When unset, each namespace keeps the default of the
      # platform release, which is off.
      enabled: false
      # Egress rules for individual platform namespaces, keyed by namespace name. Only
      # namespaces that belong to the platform itself are configured here. A namespace
      # entry overrides enabled and the matching stacks entry for that namespace.
      # Namespace names that match no platform namespace with egress rules are reported
      # in status.egress.unmatched.namespaces.
      namespaces:
        stakater-forecastle:
          # Turns egress rules on or off for this namespace. When unset, the namespace
          # follows its stacks entry, or enabled when the stack has no entry.
          enabled: true
          # Egress rules of this namespace, keyed by rule name. A rule name is a
          # lowercase DNS label. A rule that uses the name of a built-in rule changes
          # that rule; any other name adds a rule.
          rules:
            allow-cluster-nodes:
              # Position of the rule in the evaluation order. Rules with a lower number
              # are evaluated first, rules with the same number in name order. When
              # unset, a new rule gets 1000 and a built-in rule of the same name keeps
              # its position.
              priority: 300
              # Destination the rule matches: exactly one of dnsName, cidrSelector or
              # nodeSelector. Required unless the rule sets enabled to false.
              to:
                # Selects cluster nodes as the destination, by label.
                nodeSelector:
                  # Label requirements a node must meet.
                  matchExpressions:
                    # Label key the requirement applies to.
                    - key: topology.kubernetes.io/zone
                      # How the label is compared with values: In, NotIn, Exists or
                      # DoesNotExist.
                      operator: In
                      # Label values for In and NotIn. When unset, the requirement
                      # carries no values, as Exists and DoesNotExist expect.
                      values:
                        - eu-central-1a
                  # Labels a node must carry, as key and value pairs. When unset, no
                  # label is required.
                  matchLabels:
                    node-role.kubernetes.io/worker: ''
            allow-corp-network:
              # Position of the rule in the evaluation order. Rules with a lower number
              # are evaluated first, rules with the same number in name order. When
              # unset, a new rule gets 1000 and a built-in rule of the same name keeps
              # its position.
              priority: 200
              # Destination the rule matches: exactly one of dnsName, cidrSelector or
              # nodeSelector. Required unless the rule sets enabled to false.
              to:
                # Destination address range in CIDR notation, for example 10.20.0.0/16.
                # When unset, the rule matches by dnsName or nodeSelector.
                cidrSelector: 10.20.0.0/16
            allow-quay:
              # Turns this rule on or off. When unset, a new rule is on and a built-in
              # rule of the same name keeps its setting. Set false, without to, to
              # switch off a built-in rule.
              enabled: true
              # Destination ports the rule matches. When unset, the rule matches every
              # port.
              ports:
                # Destination port number.
                - port: 443
                  # Protocol of the traffic: TCP, UDP or SCTP.
                  protocol: TCP
              # Position of the rule in the evaluation order. Rules with a lower number
              # are evaluated first, rules with the same number in name order. When
              # unset, a new rule gets 1000 and a built-in rule of the same name keeps
              # its position.
              priority: 100
              # Destination the rule matches: exactly one of dnsName, cidrSelector or
              # nodeSelector. Required unless the rule sets enabled to false.
              to:
                # DNS name of the destination, for example quay.io. A leading *. matches
                # every subdomain. When unset, the rule matches by cidrSelector or
                # nodeSelector.
                dnsName: quay.io
              # Whether matching traffic is allowed or denied: Allow or Deny. When
              # unset, a new rule allows traffic and a built-in rule of the same name
              # keeps its type.
              type: Allow
            deny-everything-else:
              # Destination the rule matches: exactly one of dnsName, cidrSelector or
              # nodeSelector. Required unless the rule sets enabled to false.
              to:
                # Destination address range in CIDR notation, for example 10.20.0.0/16.
                # When unset, the rule matches by dnsName or nodeSelector.
                cidrSelector: 0.0.0.0/0
              # Whether matching traffic is allowed or denied: Allow or Deny. When
              # unset, a new rule allows traffic and a built-in rule of the same name
              # keeps its type.
              type: Deny
      # Egress rule switches for groups of platform components, one per stack. A stack
      # entry overrides enabled for every platform namespace of that stack. When a stack
      # has no entry, its namespaces follow enabled.
      stacks:
        # Egress rule switch for the backup and restore components.
        backup:
          # Turns platform-managed egress rules on or off for the platform namespaces of
          # the backup stack.
          enabled: true
        # Egress rule switch for the GitOps components that install the platform.
        bootstrap:
          # Turns platform-managed egress rules on or off for the platform namespaces of
          # the bootstrap stack.
          enabled: true
        # Egress rule switch for the pipeline, registry and code quality components.
        cicd:
          # Turns platform-managed egress rules on or off for the platform namespaces of
          # the cicd stack.
          enabled: true
        # Egress rule switch for the GitOps configuration components.
        gitops:
          # Turns platform-managed egress rules on or off for the platform namespaces of
          # the gitops stack.
          enabled: true
        # Egress rule switch for the single sign-on and access management components.
        identity:
          # Turns platform-managed egress rules on or off for the platform namespaces of
          # the identity stack.
          enabled: true
        # Egress rule switch for the ingress, load balancing and DNS components.
        networking:
          # Turns platform-managed egress rules on or off for the platform namespaces of
          # the networking stack.
          enabled: true
        # Egress rule switch for the logging, monitoring and alerting components.
        observability:
          # Turns platform-managed egress rules on or off for the platform namespaces of
          # the observability stack.
          enabled: true
        # Egress rule switch for the core platform components.
        platform:
          # Turns platform-managed egress rules on or off for the platform namespaces of
          # the platform stack.
          enabled: true
        # Egress rule switch for the secret, certificate and policy components.
        security:
          # Turns platform-managed egress rules on or off for the platform namespaces of
          # the security stack.
          enabled: false
        # Egress rule switch for the storage components.
        storage:
          # Turns platform-managed egress rules on or off for the platform namespaces of
          # the storage stack.
          enabled: true
    # Network isolation of platform namespaces. An isolated namespace accepts traffic
    # only from its own workloads, from platform monitoring, and from the sources
    # allowed for that namespace.
    isolation:
      # Turns network isolation on or off for every platform namespace that supports it.
      # An entry under stacks or namespaces overrides this value for the namespaces it
      # covers. When unset, each namespace keeps the default of the platform release,
      # which is off.
      enabled: true
      # Network isolation settings for individual platform namespaces, keyed by
      # namespace name. Only namespaces that belong to the platform itself are
      # configured here. A namespace entry overrides enabled and the matching stacks
      # entry for that namespace. Namespace names that match no isolated platform
      # namespace are reported in status.isolation.unmatched.namespaces.
      namespaces:
        stakater-forecastle:
          # Turns network isolation on or off for this namespace. When unset, the
          # namespace follows its stacks entry, or enabled when the stack has no entry.
          enabled: true
          # Allows traffic from the cluster's host network into this namespace. Set true
          # for a namespace that serves admission webhooks or aggregated APIs, which the
          # Kubernetes API server calls from the host network. When unset, the namespace
          # keeps its built-in setting.
          fromHostNetwork: false
          # Allows traffic from the cluster's ingress routers into this namespace. Set
          # true for a namespace that serves Routes. When unset, the namespace keeps its
          # built-in setting.
          fromRouter: true
          # Additional traffic allowed into this namespace, keyed by rule name. A rule
          # name is a lowercase DNS label. A rule that uses the name of a built-in rule
          # changes that rule; any other name adds a rule.
          ingress:
            from-corp-monitoring:
              # Turns this rule on or off. When unset, a new rule is on and a built-in
              # rule of the same name keeps its setting. Set false, without from, to
              # switch off a built-in rule.
              enabled: true
              # Sources allowed to connect, at least one. Traffic is allowed when it
              # matches any entry. Required unless the rule sets enabled to false.
              from:
                # An IP address range outside the cluster's pod network.
                - ipBlock:
                    # Address range in CIDR notation, for example 10.20.0.0/16.
                    cidr: 10.20.0.0/16
                    # Address ranges inside cidr that are not allowed, in CIDR notation.
                    # When unset, the whole cidr range is allowed.
                    except:
                      - 10.20.99.0/24
                # Selects source namespaces by label. An empty selector selects every
                # namespace. Without podSelector, every pod in the selected namespaces
                # is allowed.
                - namespaceSelector:
                    # Label requirements a namespace must meet.
                    matchExpressions:
                      # Label key the requirement applies to.
                      - key: environment
                        # How the label is compared with values: In, NotIn, Exists or
                        # DoesNotExist.
                        operator: In
                        # Label values for In and NotIn. When unset, the requirement
                        # carries no values, as Exists and DoesNotExist expect.
                        values:
                          - production
                    # Labels a namespace must carry, as key and value pairs. When unset,
                    # no label is required.
                    matchLabels:
                      kubernetes.io/metadata.name: corp-monitoring
                  # Selects source pods by label. With namespaceSelector, pods are
                  # matched in the selected namespaces; without it, in this namespace.
                  podSelector:
                    # Label requirements a pod must meet.
                    matchExpressions:
                      # Label key the requirement applies to.
                      - key: role
                        # How the label is compared with values: In, NotIn, Exists or
                        # DoesNotExist.
                        operator: Exists
                        # Label values for In and NotIn. When unset, the requirement
                        # carries no values, as Exists and DoesNotExist expect.
                        values: []
                    # Labels a pod must carry, as key and value pairs. When unset, no
                    # label is required.
                    matchLabels:
                      app: prober
              # Selects the pods in this namespace that the rule applies to. An empty
              # selector, the default, selects every pod in the namespace.
              podSelector:
                # Label requirements a pod must meet.
                matchExpressions:
                  # Label key the requirement applies to.
                  - key: app.kubernetes.io/component
                    # How the label is compared with values: In, NotIn, Exists or
                    # DoesNotExist.
                    operator: NotIn
                    # Label values for In and NotIn. When unset, the requirement carries
                    # no values, as Exists and DoesNotExist expect.
                    values:
                      - test
                # Labels a pod must carry, as key and value pairs. When unset, no label
                # is required.
                matchLabels:
                  app.kubernetes.io/name: forecastle
              # Ports the sources may connect to. When unset, every port is allowed.
              ports:
                # Last port of a range that starts at port. Requires a numeric port.
                # When unset, only port is allowed.
                - endPort: 8089
                  # Port number, or the name of a container port. When unset, every port
                  # of the protocol is allowed.
                  port: 8080
                  # Protocol of the traffic: TCP, UDP or SCTP. When unset, TCP applies.
                  protocol: TCP
      # Network isolation switches for groups of platform components, one per stack. A
      # stack entry overrides enabled for every platform namespace of that stack. When a
      # stack has no entry, its namespaces follow enabled.
      stacks:
        # Network isolation switch for the backup and restore components.
        backup:
          # Turns network isolation on or off for the platform namespaces of the backup
          # stack.
          enabled: true
        # Network isolation switch for the GitOps components that install the platform.
        bootstrap:
          # Turns network isolation on or off for the platform namespaces of the
          # bootstrap stack.
          enabled: true
        # Network isolation switch for the pipeline, registry and code quality
        # components.
        cicd:
          # Turns network isolation on or off for the platform namespaces of the cicd
          # stack.
          enabled: true
        # Network isolation switch for the GitOps configuration components.
        gitops:
          # Turns network isolation on or off for the platform namespaces of the gitops
          # stack.
          enabled: true
        # Network isolation switch for the single sign-on and access management
        # components.
        identity:
          # Turns network isolation on or off for the platform namespaces of the
          # identity stack.
          enabled: true
        # Network isolation switch for the ingress, load balancing and DNS components.
        networking:
          # Turns network isolation on or off for the platform namespaces of the
          # networking stack.
          enabled: true
        # Network isolation switch for the logging, monitoring and alerting components.
        observability:
          # Turns network isolation on or off for the platform namespaces of the
          # observability stack.
          enabled: true
        # Network isolation switch for the core platform components.
        platform:
          # Turns network isolation on or off for the platform namespaces of the
          # platform stack.
          enabled: true
        # Network isolation switch for the secret, certificate and policy components.
        security:
          # Turns network isolation on or off for the platform namespaces of the
          # security stack.
          enabled: false
        # Network isolation switch for the storage components.
        storage:
          # Turns network isolation on or off for the platform namespaces of the storage
          # stack.
          enabled: true
```

## What's Next?

- [Platform Configuration APIs](overview.md) - How the platform configuration APIs work, and who can use them
- [Release Notes](../release-notes/index.md) - What changes in each release
- [Platform Configuration](../installation/configuration.md) - Override settings no platform configuration API covers yet
