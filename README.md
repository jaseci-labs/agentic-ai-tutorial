# JacHacks: Build an AI Agent in 30 Minutes

Learn the 4 core primitives of agentic AI — and build a working **Hackathon Pitch Builder** agent along the way.

> This repo also doubles as a **reference for AI coding assistants** working on Jac projects. See [CLAUDE.md](CLAUDE.md) for the full patterns guide.

---

## What We're Building

A Hackathon Pitch Builder: you give it your interests and skills, and it brainstorms ideas, structures a pitch, researches similar projects, and routes you to the right domain mentor — all autonomously.

We build it in 4 steps, one primitive per step.

---

## Setup

```bash
# 1. Install the Jac runtime
pip install jaseci

# 2. Set your OpenAI API key (you'll get one at the start of the session)
export OPENAI_API_KEY="your-key-here"
```

---

## Run the Full App (web UI)

After the workshop — or to demo during it — run the full web app:

```bash
jac start app.jac
# open http://localhost:8000
```

This starts a server with the complete Hackathon Pitch Builder UI.
All 4 steps are wired together in the browser — each step unlocks when the previous one completes.

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

---

## The 4 Primitives

### Step 1 — Generate

The LLM fills in any function body. The signature IS the prompt.

```jac
"""Brainstorm 3 creative hackathon project ideas based on interests and skills."""
def brainstorm_ideas(interests: str, skills: str) -> str by llm();
```

---

### Step 2 — Extract

Return a typed object instead of `str`. The compiler enforces the schema — no JSON parsing, no "parse and pray."

```jac
obj HackathonPitch {
    has title: str;
    has problem: str;
    has tech_stack: list[str];
    has difficulty: Difficulty;
    has track: Track;
}

"""Turn a raw hackathon idea into a structured, compelling pitch."""
def structure_pitch(raw_idea: str) -> HackathonPitch by llm();
```

---

### Step 3 — Invoke

Give the LLM a list of tools. It decides which to call, reads the results, and loops until it has a complete answer (ReAct cycle).

```jac
"""Research a hackathon idea: find similar GitHub projects, suggest a tech stack,
and estimate if it's buildable in 24 hours."""
def research_idea(idea: str) -> str by llm(
    tools=[search_github, describe_tech_stack, estimate_build_time]
);
```

---

### Step 4 — Route

The LLM reads node descriptions and picks where a walker goes. No if/else. The graph IS the routing table.

```jac
walker HackathonAdvisor {
    has pitch: str;

    can route with Root entry {
        visit [-->] by llm(incl_info={"Hackathon pitch": self.pitch});
    }
}
```

---

## There Are 3 More Primitives

This workshop covers the 4 most important ones. Jac has 7 total:

| Primitive | What it does |
|-----------|-------------|
| **Generate** | LLM returns free text |
| **Extract** | LLM returns typed, schema-validated data |
| **Invoke** | LLM calls tools in a ReAct loop |
| **Route** | LLM picks a path through a graph |
| **Pipe** | Chain operations sequentially (output → next input) |
| **Loop** | Repeat until a typed quality check passes |
| **Spawn** | Run multiple walkers in parallel and merge results |

See [CLAUDE.md](CLAUDE.md) for complete working examples of all 7 primitives.

---

## Resources

- Jac docs: https://docs.jaseci.org
- Jaseci GitHub: https://github.com/Jaseci-Labs/jaseci
- JacHacks: https://jachacks.org
- Community Discord: https://discord.gg/6j3QNdtcN6
