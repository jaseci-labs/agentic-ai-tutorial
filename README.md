# JacHacks: Build an AI Agent in 30 Minutes

Learn the 4 core patterns of agentic AI — and build a working **Hackathon Pitch Builder** agent along the way.

📖 **[Browse the snippets online →](https://jaseci-labs.github.io/agentic-ai-tutorial/)**

> This repo also doubles as a **reference for AI coding assistants** working on Jac projects. See [CLAUDE.md](CLAUDE.md) for the full patterns guide.

---

## What We're Building

A Hackathon Pitch Builder: you give it your interests and skills, and it brainstorms ideas, structures a pitch, researches similar projects, and routes you to the right domain mentor — all autonomously.

We build it in 4 steps, one pattern per step:

| Step | Pattern | File |
|------|-----------|------|
| 1 | **Generate** — `by llm()` free-form output | [step1_generate.jac](step1_generate.jac) |
| 2 | **Extract** — `by llm()` with a typed `obj` return | [step2_extract.jac](step2_extract.jac) |
| 3 | **Invoke** — `by llm(tools=[...])` with ReAct tool calling | [step3_invoke.jac](step3_invoke.jac) |
| 4 | **Route** — walker visits LLM-chosen nodes in parallel | [step4_route.jac](step4_route.jac) |

Then all four compose into a streaming chat agent — [agent.jac](agent.jac).

---

## Setup

Requires **Jac 0.34 or newer** (`jac --version`).

```bash
# 1. Install the Jac runtime (standalone binary)
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash -s -- --standalone
export PATH="$HOME/.local/bin:$PATH"

# 2. Install project dependencies
jac install

# 3. Set your OpenAI API key (you'll get one at the start of the session)
export OPENAI_API_KEY="your-key-here"
```

`jac install` is not optional. The LLM capability (litellm and friends) is declared
by the `[byllm.model]` table in `jac.toml` and is only fetched by that step — skip it
and the first `by llm()` call fails with `'litellm' is required for this feature`.

Check everything compiles:

```bash
jac check app.jac
```

---

## Follow Along

Run each step standalone — no UI, just the pattern in isolation:

```bash
jac run step1_generate.jac
jac run step2_extract.jac
jac run step3_invoke.jac
jac run step4_route.jac
```

---

## Run the App

```bash
jac start app.jac
# open http://localhost:8000
```

Two tabs:

- **Guided build** — the 4 patterns as a step-by-step form; each step unlocks when the previous one completes.
- **Agent chat** — all 4 composed into one streaming agent, with the agent's own architecture drawn beside the conversation.

---

## The Agent — `agent.jac`

The chat tab is not a tool-loop. The agent is a **graph**, and the walker's
position in it is the agent's state:

```
Perceive ──> Plan ──> Act ──> Synthesize
                       │
                       ├── Brainstorm   (Generate)
                       ├── Structure    (Extract)
                       ├── Research     (Invoke — tools/ReAct)
                       └── Mentors      (Route + Spawn)
```

What makes it worth copying rather than just wiring tools onto a loop:

- **The graph is the architecture.** Topology is data under `root`.
  `agent_architecture()` reads that same graph back, so the diagram in the UI is
  derived from the running system and cannot drift from it.
- **Behaviour lives on nodes.** Each capability implements its own
  `can ... with CapabilityExec entry`. Adding a capability means adding a node,
  not editing a dispatch chain.
- **Typed contracts between stages.** Perceive returns an `Intent`, Plan returns
  a `Plan` — `obj`s the compiler enforces, not free text the next stage re-parses.
- **The plan directs the route.** Small talk runs *zero* capabilities; a full
  pitch request runs four. Nothing is hardcoded.
- **Cognition is separate from transport.** Stages know nothing about HTTP;
  `agent_chat_stream` is a thin SSE adapter. Swap it for a CLI and nothing changes.
- **The agent narrates itself.** Stages, capabilities and individual tool calls
  publish to one event bus, so the trace the UI draws *is* the execution path.
  Capabilities run on a worker thread while the endpoint drains that bus — which
  is why a tool call appears the moment it happens, not after the step finishes.

Streaming is real SSE: `def:pub ... -> Generator` with `report stream()`, and the
final answer streams token by token via `by llm(stream=True)`.

**Frontend files:**
```
frontend/
├── App.cl.jac     ← main layout + state management
├── Step1.cl.jac   ← Generate: brainstorm form
├── Step2.cl.jac   ← Extract: structured pitch cards
├── Step3.cl.jac   ← Invoke: research + GitHub results
├── Step4.cl.jac   ← Route: mentor advice
└── styles.css     ← dark hackathon theme
```

Server walkers in `app.jac` become HTTP endpoints automatically. The client
imports them and spawns them directly:

```jac
sv import from ...app { run_brainstorm }

result = root spawn run_brainstorm(interests=interests, skills=skills);
ideas  = result.reports[0];
```

---

## Jac 0.34 Notes

Two that are easy to get wrong even after the code compiles:

- **`flow root spawn` returns a *future*, not the walker.** Collect it with
  `w = (wait f) as AdviceWorker;` — without the `as` cast, attribute access
  fails to type-check (`E1032`).
- **`visit` is deferred.** Node abilities run only *after* the current ability
  returns, so a walker can't route and collect results in the same ability.
  `step4_route.jac` gathers results at a later `CollectNode`.

Also worth knowing: declare `by llm()` functions with **`def:pub`**. A plain
`def ... by llm()` returns `None` at runtime under `jac run`.

---

## Resources

- Jac docs: https://docs.jaseci.org
- Jaseci GitHub: https://github.com/Jaseci-Labs/jaseci
- JacHacks: https://jachacks.org
- Community Discord: https://discord.gg/6j3QNdtcN6
