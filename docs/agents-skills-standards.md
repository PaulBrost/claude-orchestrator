# Agents, Skills and Standards

Three ways to make knowledge reusable across projects. They look interchangeable and are not. This
document explains what each one is for, why this orchestrator leans hard on standards and skills
while defining almost no agents, and how to tell which one a new piece of reusable knowledge wants
to be.

## The short version

| | Answers | Lives in | Read by | Loaded |
|---|---|---|---|---|
| **Standard** | *What must the result satisfy?* | `standards/*.md` | whoever executes the work | by path, quoted into a delegation prompt |
| **Skill** | *How do I carry out this repeated task?* | `.claude/skills/<name>/SKILL.md` | the orchestrator | on demand, when invoked |
| **Agent** | *Who does the work, with what tools and what standing knowledge?* | `.claude/agents/<name>.md` | n/a — it *is* an executor | when delegated to |

The distinction that matters most: a **standard is declarative** (a contract on the output), a
**skill is imperative** (a procedure), and an **agent is an executor** (a context boundary with
tools attached). Mixing them up produces things that don't work — most commonly an "agent" that is
really a paragraph of instructions wearing a costume.

One structural note: **standards are not a harness feature.** Skills and agents are Claude Code
primitives with defined file locations and loading behaviour. A standard is just a markdown file
this orchestrator has agreed to reference. That sounds like a weakness and is actually the source of
its main advantage — see below.

---

## Why this orchestrator defines almost no agents

The obvious idea, when you have many related projects, is a cast of reusable roles: a *developer*
agent, a *QA* agent, a *UI design* agent, one per integration. It reads as the natural next step
after "delegate to sub-agents." It mostly isn't, for four reasons.

**1. Sub-agents start with empty context, so a persona adds nothing.** A fresh agent needs the
project path, the task, the acceptance criteria, the cross-project impacts, the verification steps
and the relevant standards spelled out in its prompt no matter what its system prompt calls it.
Telling it "you are a senior engineer" adds no information the prompt did not already have to carry.
The delegation checklist in `CLAUDE.md` is doing the real work, and it varies *per project*, not per
role.

**2. The general-purpose agent already is the developer agent.** A `developer` definition would
largely restate defaults, and then need maintaining.

**3. The bottleneck is context assembly, not role.** The expensive part of a delegation is deciding
which facts out of a large registry belong in this particular prompt, and remembering which
standards attach. A role taxonomy touches neither.

**4. Job titles are the wrong seam.** Roles cut across projects horizontally; the knowledge that is
actually expensive to re-derive is vertical — a subsystem's topology, a pipeline's silent traps, a
deployment's history. When a definition *is* worth writing, it wants to be a **domain**, not a
title.

Note what does *not* appear on that list: "agents are bad." They are excellent when they earn their
keep. The test below is how to tell.

---

## When an agent earns its definition

An agent definition pays for itself only when it encodes something a prompt cannot cheaply carry.
There are four such things:

1. **Tool restriction.** A reviewer that structurally *cannot* write is a different thing from one
   asked politely not to. This is the strongest single reason to define an agent, and it is
   enforcement rather than instruction.
2. **Model pinning.** So a class of work routes to a cheap or expensive model without re-deciding
   each time.
3. **Context isolation.** Long searches, log sweeps and verbose external output stay out of the
   orchestrator's window. You keep the conclusion, not the dump.
4. **Standing domain knowledge.** Facts that are stable, reused constantly, and expensive to
   re-explain — the shape of an infrastructure estate, the traps in a cross-project pipeline.

**If none of the four applies, what you have is a prompt, not an agent.** Write it as a delegation
and move on.

A useful corollary: an "integration" agent — Jira, email, a ticketing system — is almost never
agent-shaped. An agent with no tool that reaches the service is a persona that cannot act. The
right unit there is an MCP server or CLI (the capability) plus a skill (the workflow).

### On sub-orchestrators

A tempting extension is a routing layer: a thin top orchestrator that only decides *which domain*
a request belongs to, delegating to per-domain sub-orchestrators that in turn delegate to workers.
Sub-agents can spawn their own sub-agents, so this is buildable. It usually should not be built.

- **Routing correctly requires the knowledge you were trying to defer.** Incidents present as a
  symptom in one domain and originate in another; a router choosing by surface symptom mis-routes
  precisely the cases that matter most, and cross-domain fixes land in both places.
- **You pay for the same context twice.** A domain sub-orchestrator loads its domain knowledge, then
  has to retype the relevant slice into a worker's fresh prompt anyway.
- **Splitting by organisational category** (work vs personal, team A vs team B) tends to silo the
  couplings the orchestrator exists to see, because real dependencies rarely respect those lines.

A genuine sub-orchestrator earns its place by **task shape, not subject area**: long-running,
internal fan-out, and voluminous intermediate output nobody wants to read. A staged migration is
that shape. "Everything about subsystem X" is not — that is a context bundle, and bundles want lazy
loading, not a delegation hop.

Prefer, therefore: **domain agents that are executors carrying standing knowledge, not routers.**

---

## Standards vs skills

These overlap enough to be worth separating carefully, because the temptation is to collapse them.

### A standard is a contract on the output

`standards/documentation.md` says documentation is updated in the same change as the code it
describes. A UI standard says text must meet a measured contrast ratio. Neither describes a
procedure. Both describe what a finished result must be true of, and both are checkable against a
diff by someone who never saw the prompt.

Standards have three properties skills do not:

- **They reach any executor.** A skill is a Claude Code primitive; an external CLI, or a session
  opened directly inside a project rather than here, cannot see one. A standard is a plain file that
  travels by path or by being quoted inline, so it reaches whatever is doing the work.
- **They survive leaving the orchestrator.** Projects can carry a pointer line in their own
  `CLAUDE.md` / `AGENTS.md`, so the rule holds in sessions that never load this repo.
- **They are the shareable artifact.** `standards.example/` is what someone else adopts. A procedure
  tuned to one person's registry is not.

There is one trap that comes with travel-by-path, worth stating because it fails silently: a path is
only useful if the executor can actually read it. A sandboxed CLI given an absolute path outside its
working directory may be unable to open it, produce a confident and well-formed result anyway, and
report success on everything else it was asked to do. If you cannot guarantee the read, inline the
standard's text into the prompt.

### A skill is a procedure for the orchestrator

`audit-docs` sweeps the registry, fans out read-only agents, aggregates a report and records a
timestamp. That is a sequence with steps, state and fan-out — nothing declarative about it, and
nothing another executor needs to read.

Skills earn their place through **progressive disclosure**: only the one-line description sits in
context until the skill is invoked, so a dozen procedures cost almost nothing until used. That makes
them the right home for anything you do repeatedly but not constantly.

### They compose — that is the point

The two are not competing descriptions of the same thing. They are two halves of one enforcement
loop:

> `standards/documentation.md` defines what compliance **is**.
> The `audit-docs` skill is how the orchestrator **detects** non-compliance.
> The delegation rule in `CLAUDE.md` is how it **prevents** it.

Prevention, detection, definition. Any rule you actually care about wants all three, and the
definition half is the standard.

---

## Choosing, in practice

Ask what kind of thing you are trying to make reusable:

| If it is… | Make it a… |
|---|---|
| A rule the *output* must satisfy, checkable against a diff | **Standard** |
| A rule that must reach an executor outside this orchestrator | **Standard** (inline it if the path may not be readable) |
| A multi-step procedure *you* repeat — sweep, report, deploy, cut over | **Skill** |
| Something you do rarely but that has an easy-to-forget sequence | **Skill** |
| Work that must be structurally prevented from writing | **Agent** (tool restriction) |
| Work that should always run on a cheaper or stronger model | **Agent** (model pinning) |
| Work that produces output you never want in your own context | **Agent** (context isolation) |
| A body of stable domain knowledge you re-explain constantly | **Agent** (standing knowledge) |
| A paragraph you are tired of typing into prompts | **Nothing yet.** Keep typing it. Promote it once it recurs with the same shape three or four times. |

### When you want both

The common case is a rule with teeth. You need a **standard** (the contract), and then one or both
of:

- a **skill**, if checking or applying it is a procedure rather than a judgement, and
- an **agent**, if the checking must be done by something that cannot also perform the fix.

A concrete shape: a documentation standard, an audit skill that sweeps for violations, and a
read-only verifier agent that reports without repairing. Three mechanisms, one rule, each doing the
part the others cannot.

### What we do here instead of a role taxonomy

- Keep the registry index **thin** and push per-project detail into files loaded on demand — this is
  the change that most reduces the cost of every session, and it is neither an agent nor a skill.
- Attach standards **by path** in every delegation prompt, inlining where the executor's access is
  uncertain.
- Write a **skill** for each procedure that recurs.
- Define an **agent** only when one of the four tests passes — and cut it along a domain, never a
  job title.

The bar for adding a mechanism is that it removes work you are actually doing, repeatedly, today.
Speculative infrastructure for imagined workflows is the failure mode all three of these share.
