# JacHacks: Build an AI Agent in 30 Minutes

Learn the 4 core patterns of agentic AI — and build a working **Hackathon Pitch Builder** agent along the way.

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

```bash
# 1. Install the Jac runtime
pip install jaseci

# 2. Set your OpenAI API key (you'll get one at the start of the session)
export OPENAI_API_KEY="your-key-here"
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

## Build It Yourself: `app_tutorial.jac`

[app_tutorial.jac](app_tutorial.jac) is the full app scaffold with the four HTTP endpoints stubbed as `TODO` placeholders. Each one is a `walker:pub` — Jac auto-generates the REST endpoint when you run `jac start`.

Your job: fill in the four walkers so the React frontend can call them.

```jac
walker:pub run_brainstorm {
    # has interests: str;
    # has skills: str;
    # can do with Root entry {
    #     report brainstorm_ideas(self.interests, self.skills);
    # }
}
```

Each TODO comment tells you which fields the frontend sends, which pattern to call, and what to `report`. When all four are filled in:

```bash
jac start app_tutorial.jac
# open http://localhost:8000
```

---

## Run the Finished App

The completed version is in [app.jac](app.jac):

```bash
jac start app.jac
# open http://localhost:8000
```

All 4 steps wired together in the browser — each step unlocks when the previous one completes.

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

The frontend calls each walker with:

```jac
result = root spawn run_brainstorm(interests=interests, skills=skills);
ideas  = result.reports[0];
```

---

## Resources

- Jac docs: https://docs.jaseci.org
- Jaseci GitHub: https://github.com/Jaseci-Labs/jaseci
- JacHacks: https://jachacks.org
- Community Discord: https://discord.gg/6j3QNdtcN6
