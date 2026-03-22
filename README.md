# ASPLOS '26 Tutorial: Building Agentic AI Systems with Jac

Learn to build agentic AI systems using **Jac** — a language designed around the 7 primitives of agentic computation. By the end of this tutorial you will have built a self-correcting, parallel research agent from scratch, one primitive at a time.

---

## What You Will Learn

This tutorial introduces 7 composable primitives split into two layers:

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

## Running the Steps

Each step is a self-contained `.jac` file in the `code/` directory:

```bash
jac run code/step1_generate.jac
jac run code/step2_extract.jac
jac run code/step3_invoke.jac
jac run code/step4_pipe.jac
jac run code/step5_route.jac
jac run code/step6_loop.jac
jac run code/step7_spawn.jac
jac run code/step8_composition.jac
```

Each file begins with a docstring explaining the primitive covered, what it builds on, and what to observe in the output.

---

## Resources

- Jac documentation: https://docs.jaseci.org
- Jaseci GitHub: https://github.com/Jaseci-Labs/jaseci
- Community Discord: https://discord.gg/6j3QNdtcN6
