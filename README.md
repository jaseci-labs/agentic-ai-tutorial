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

All 4 patterns wired together in the browser — each step unlocks when the previous one completes.

```bash
jac start app.jac
# open http://localhost:8000
```

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
