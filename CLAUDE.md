# Jac Agentic Patterns Reference

This file exists so AI coding assistants understand how Jac's agentic primitives work.
When you see Jac code in this project, use this guide to understand and extend it correctly.

---

## Language Basics

Jac is a Python-substrate language. Most Python libraries work via `import`.
Statements end with `;`. Blocks use `{ }`.

```jac
import json;
import from urllib.request { urlopen }

def greet(name: str) -> str {
    return f"Hello, {name}!";
}
```

---

## The 7 Agentic Primitives

### 1. Generate — `by llm()`

Delegate a function body to the LLM. The function signature (name + params + return type + docstring) becomes the prompt.

```jac
"""Answer any question with a thoughtful, concise response."""
def answer(question: str) -> str by llm();
```

**Rules:**
- The docstring guides LLM behavior — write it like an instruction.
- Return type must be `str` for free text.
- No function body needed; `by llm()` replaces it.

---

### 2. Extract — `by llm()` with a typed return

Same as Generate, but returns a typed `obj`. The compiler enforces the schema.

```jac
enum Sentiment { POSITIVE, NEGATIVE, NEUTRAL }

obj Review {
    has sentiment: Sentiment;
    has score: int;           # 1-10
    has summary: str;
    has pros: list[str];
    has cons: list[str];
}

"""Analyze a product review and extract structured feedback."""
def analyze_review(review_text: str) -> Review by llm();
```

**Rules:**
- Define schemas with `obj`. Fields use `has field: type;`.
- Use `enum` for categorical fields — prevents invalid values.
- `list[str]`, `list[int]`, nested `obj` types all work.
- The LLM cannot return malformed data; the compiler rejects it.

---

### 3. Invoke — `by llm(tools=[...])`

Give the LLM callable functions. It runs a ReAct loop: reason → call tool → observe result → repeat until done.

```jac
def search_web(query: str) -> str { ... }       # regular function
def summarize(text: str) -> str by llm();        # LLM function used as tool

"""Research a topic using web search and summarization."""
def research(topic: str) -> str by llm(tools=[search_web, summarize]);
sem research = "Research a topic thoroughly before answering.";
```

**Rules:**
- Tools are just normal Jac functions — the LLM calls them by name.
- `sem` (semantic annotation) tells the LLM *why* to call each function.
- Add `sem` to tools too: `sem search_web = "Search the web for information.";`
- The LLM decides the call order and stops when it has enough information.

---

### 4. Pipe — `|>`

Chain functions so the output of one becomes the input of the next.

```jac
def draft(topic: str) -> str by llm();
def improve(draft: str) -> str by llm();
def shorten(text: str) -> str by llm();

with entry {
    result = "quantum computing" |> draft |> improve |> shorten;
}
```

**Rules:**
- Each function's output type must match the next function's first parameter type.
- Pure sequential — no branching, no parallelism.

---

### 5. Route — `visit [-->] by llm(...)`

Walker visits one of N child nodes. The LLM reads each node's fields/description and picks the best match. No if/else chains — the graph IS the routing table.

```jac
node ExpertA {
    has description: str = "Expert in topic A";

    can respond with MyWalker entry {
        visitor.result = "Expert A answered: " + visitor.query;
    }
}

node ExpertB {
    has description: str = "Expert in topic B";

    can respond with MyWalker entry {
        visitor.result = "Expert B answered: " + visitor.query;
    }
}

walker MyWalker {
    has query: str;
    has result: str = "";

    can route with Root entry {
        visit [-->] by llm(incl_info={"User query": self.query});
    }
}

with entry {
    root ++> ExpertA();
    root ++> ExpertB();
    w = root spawn MyWalker(query="something about topic B");
    print(w.result);
}
```

**Rules:**
- `[-->]` means "all child nodes of the current node."
- `incl_info={...}` passes extra context to the LLM for its routing decision.
- The LLM reads node field values (like `description`) to decide.
- `can <ability> with <NodeType> entry { ... }` fires when the walker arrives at that node type.
- `visitor` inside a node ability refers to the visiting walker.

---

### 6. Loop — Repeat until quality gate passes

Combine Generate + Extract to self-correct: generate → evaluate → improve → repeat.

```jac
enum Quality { GOOD, NEEDS_WORK }

obj Evaluation {
    has verdict: Quality;
    has feedback: str;
}

"""Write a compelling product description."""
def write_description(product: str) -> str by llm();

"""Evaluate whether a product description is ready to publish."""
def evaluate(description: str) -> Evaluation by llm();

"""Improve a product description based on specific feedback."""
def improve(description: str, feedback: str) -> str by llm();

with entry {
    draft = write_description("wireless noise-canceling headphones");
    for i in range(3) {   # max 3 rounds
        review = evaluate(draft);
        if review.verdict == Quality.GOOD { break; }
        draft = improve(draft, review.feedback);
    }
    print(draft);
}
```

**Rules:**
- Use `Extract` (typed return) for the quality gate — never `str` — so you can branch on the verdict.
- Always cap the loop with a `range(N)` guard to prevent infinite loops.

---

### 7. Spawn — Parallel walkers

Launch multiple walkers concurrently and wait for all to finish.

```jac
walker ResearcherA {
    has topic: str;
    has findings: str = "";

    can research with Root entry {
        self.findings = do_research(self.topic);  # runs in parallel
    }
}

walker ResearcherB {
    has topic: str;
    has findings: str = "";

    can research with Root entry {
        self.findings = do_research(self.topic);
    }
}

with entry {
    # flow spawn = launch without blocking; collect results after
    a = root flow spawn ResearcherA(topic="topic A");
    b = root flow spawn ResearcherB(topic="topic B");

    # walkers run in parallel; access .findings after both complete
    print(a.findings);
    print(b.findings);
}
```

**Rules:**
- `flow spawn` launches asynchronously; `spawn` blocks until done.
- Each walker has its own isolated state (`has` fields).
- Collect results by reading walker fields after spawning.

---

## Graph Operators Cheatsheet

| Operator | Meaning |
|----------|---------|
| `root ++> NodeType()` | Create node and connect to root |
| `a ++> b` | Connect node `a` to node `b` |
| `[-->]` | All child nodes of current node |
| `root spawn Walker(...)` | Launch walker from root (blocking) |
| `root flow spawn Walker(...)` | Launch walker from root (non-blocking) |

---

## Semantic Annotations (`sem`)

`sem` attaches a plain-English description to a function or type. The LLM reads `sem` annotations to understand when/why to call things.

```jac
def fetch_weather(city: str) -> str { ... }
sem fetch_weather = "Get the current weather for a city. Call this when the user asks about weather conditions.";

# Also works on methods:
sem MyNode.my_method = "What this method does and when the LLM should call it.";
```

Always add `sem` to tool functions used in `by llm(tools=[...])`.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Returning `str` from Extract | Use a typed `obj` return |
| No `sem` on tools | Add `sem tool_name = "..."` for every tool |
| Forgetting `++>` to connect nodes | Connect all nodes to `root` before spawning walker |
| Infinite Loop | Always cap with `for i in range(N)` |
| Missing semicolons | Every statement ends with `;` |
