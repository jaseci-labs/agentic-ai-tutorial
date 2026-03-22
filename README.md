# ASPLOS '26 Tutorial: Building Agentic AI Systems with Jac

Learn to build agentic AI systems using **Jac** — a language designed around the 7 primitives of agentic computation. By the end of this hands-on session you will have built a self-correcting, parallel research agent from scratch, one primitive at a time.

---

## Repository Structure

```
exercises/          <- You work here (skeletons with TODOs)
solutions/          <- Reference solutions (peek if stuck)
output/             <- Generated markdown files (created at runtime)
```

---

## What You Will Build

**Mind primitives** — what the LLM does:

| Step | Primitive | What it does |
|------|-----------|--------------|
| 1 | **Generate** | LLM returns free text from a function signature |
| 2 | **Extract** | LLM returns structured, typed data — enforced by the compiler |
| 3 | **Invoke** | LLM calls tools, observes results, and loops (ReAct cycle) |

**Flow primitives** — how work moves:

| Step | Primitive | What it does |
|------|-----------|--------------|
| 4 | **Pipe** | Chain operations sequentially |
| 5 | **Route** | LLM picks a path from a graph of nodes |
| 6 | **Loop** | Repeat until a typed quality check passes |
| 7 | **Spawn** | Run multiple walkers in parallel and merge results |

**Step 8** puts all 7 together into a single self-correcting parallel research agent.

---

## Setup

### 1. Run the setup script

```bash
source setup.sh
```

This will:
- Install the Jac language runtime (standalone binary)
- Add `jac` to your PATH

### 2. Set your API key

You will receive an OpenAI API key at the start of the tutorial. Export it in your terminal:

```bash
export OPENAI_API_KEY="your-key-here"
```

---

## How to Work Through the Exercises

Each exercise file has **TODO** markers where you write the key primitive. The boilerplate and types are provided.

### 1. Open the exercise

```bash
# Work in the exercises/ directory
cd exercises/
```

### 2. Fill in the TODOs

Open `step1.jac` in your editor. Look for the `# TODO` comments — they tell you exactly what to write.

### 3. Run your code

```bash
jac run step1.jac
```

### 4. View the output

Each step writes a markdown file to `output/`. Open it to see your results formatted nicely:

```bash
# On macOS
open output/step1_generate.md

# Or just cat it
cat output/step1_generate.md
```

### 5. If you get stuck

The complete solution is in `solutions/`:

```bash
jac run ../solutions/step1_generate.jac
```

---

## Exercise Progression

```bash
# Mind primitives
jac run step1.jac    # Generate: LLM returns free text
jac run step2.jac    # Extract:  LLM returns typed data
jac run step3.jac    # Invoke:   LLM calls tools (ReAct)

# Flow primitives
jac run step4.jac    # Pipe:     Sequential chaining
jac run step5.jac    # Route:    LLM-directed graph traversal
jac run step6.jac    # Loop:     Self-correction cycle
jac run step7.jac    # Spawn:    Parallel walkers

# Capstone
jac run step8.jac    # All 7 primitives in one agent
```

---

## Resources

- Jac documentation: https://docs.jaseci.org
- Jaseci GitHub: https://github.com/Jaseci-Labs/jaseci
- Community Discord: https://discord.gg/6j3QNdtcN6
