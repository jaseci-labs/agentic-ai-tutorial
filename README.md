# Hackathon Pitch Builder — Agentic AI with Jac

A full-stack agentic app built with **Jac**, plus four standalone snippets that
each demonstrate one agentic primitive on its own.

The app takes a rough project idea and walks it through four LLM-driven stages:
brainstorm ideas → structure a typed pitch → research it with tools → route it to
the right expert mentors for advice.

---

## Repository Structure

```
app.jac             <- The app: server functions + client entry
frontend/           <- Client components (.cl.jac) + styles.css
tools.jac           <- Shared tools the LLM can call (GitHub search, etc.)

step1_generate.jac  <- Standalone snippet: Generate
step2_extract.jac   <- Standalone snippet: Extract
step3_invoke.jac    <- Standalone snippet: Invoke
step4_route.jac     <- Standalone snippet: Route + Spawn

output/             <- Markdown written by the snippets (created at runtime)
```

---

## Setup

Requires **Jac 0.34 or newer** (`jac --version`).

### 1. Install the Jac binary

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash -s -- --standalone
export PATH="$HOME/.local/bin:$PATH"
```

### 2. Install project dependencies

```bash
jac install
```

Not optional: the LLM capability (litellm and friends) is declared by the
`[byllm.model]` table in `jac.toml` and is only fetched by this step. Skipping it
gives you `'litellm' is required for this feature` on the first `by llm()` call.

### 3. Set your API key

```bash
export OPENAI_API_KEY="your-key-here"
```

### 4. Check everything compiles

```bash
jac check app.jac
```

---

## Run the App

```bash
jac start app.jac
# open http://localhost:8000
```

Server functions in `app.jac` are exposed automatically as HTTP endpoints
(`run_brainstorm`, `run_structure`, `run_research`, `run_route`); the client
components in `frontend/` call them via `sv import`.

---

## The Four Snippets

Each file runs on its own and writes its result to `output/`.

```bash
jac run step1_generate.jac   # Generate: LLM returns free text
jac run step2_extract.jac    # Extract:  LLM returns a typed object
jac run step3_invoke.jac     # Invoke:   LLM calls tools in a ReAct loop
jac run step4_route.jac      # Route:    LLM picks expert nodes, spawns workers
```

| Snippet | Primitive | What it shows |
|---------|-----------|---------------|
| `step1_generate.jac` | **Generate** | A function signature becomes the prompt; `by llm()` supplies the body |
| `step2_extract.jac` | **Extract** | A typed `obj` return with `enum` fields — the compiler enforces the schema |
| `step3_invoke.jac` | **Invoke** | `by llm(tools=[...])` runs reason → call tool → observe → repeat |
| `step4_route.jac` | **Route + Spawn** | `visit [-->] by llm()` picks expert nodes; each spawns a parallel worker |

`step4_route.jac` also shows the two things that trip people up: `flow root spawn`
returns a *future* (collect it with `(wait f) as Worker`), and `visit` is
*deferred*, so results are gathered at a later collector node rather than inline.

See `CLAUDE.md` for a syntax reference covering these primitives.

---

## Resources

- Jac documentation: https://docs.jaseci.org
- Jaseci GitHub: https://github.com/Jaseci-Labs/jaseci
- Community Discord: https://discord.gg/6j3QNdtcN6
