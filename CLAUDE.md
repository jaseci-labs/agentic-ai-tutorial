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
- Each ability in one walker needs a **unique name** — you cannot have two
  `can respond with ...` blocks in the same walker (`E0076: Duplicate method`).
  Name them per node: `can route_web with WebNode entry`, etc.

**`visit` is deferred — you cannot route and collect in the same ability.**
Node abilities run only *after* the current ability body returns, so anything
the visited nodes produce is not there yet:

```jac
can route with Root entry {
    visit [-->] by llm(incl_info={"query": self.query});
    for w in self.workers { ... }   # WRONG: self.workers is still empty here
}
```

Queue a collector node last and gather results when the walker arrives there:

```jac
node CollectNode {}

can route with Root entry {
    visit [-->] by llm(incl_info={"query": self.query});
    visit collect;                  # queued after the experts
}

can gather with CollectNode entry {
    for f in self.workers { ... }   # now every expert has run
}
```

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

Launch multiple walkers concurrently, then `wait` for them.

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
    # `flow root spawn` (in that order) launches without blocking and
    # returns a FUTURE — not the walker.
    ta = flow root spawn ResearcherA(topic="topic A");
    tb = flow root spawn ResearcherB(topic="topic B");

    # Launch everything first, then wait. `wait` gives back the finished
    # walker, but the checker sees it as Unknown — bind it with `as`.
    a = (wait ta) as ResearcherA;
    b = (wait tb) as ResearcherB;

    print(a.findings);
    print(b.findings);
}
```

**Rules:**
- The keyword order is `flow root spawn W(...)`, not `root flow spawn W(...)`.
- `flow ... spawn` returns a future; `spawn` blocks and returns the walker.
- Always `(wait f) as WalkerType` — without the cast you get
  `E1032: Type is Unknown, cannot access attribute ...`.
- Launch all, then wait all. A `wait` right after each `flow` runs them serially.
- To `wait` a mixed list of walker types, give them a common base walker
  (`walker HW(Researcher) { ... }`) and cast to that base.

---

## Graph Operators Cheatsheet

| Operator | Meaning |
|----------|---------|
| `root ++> NodeType()` | Create node and connect to root |
| `a ++> b` | Connect node `a` to node `b` |
| `[-->]` | All child nodes of current node |
| `root spawn Walker(...)` | Launch walker from root (blocking, returns walker) |
| `flow root spawn Walker(...)` | Launch walker from root (non-blocking, returns future) |
| `(wait f) as Walker` | Block on a future and bind its walker type |

Note: `root` is a bare keyword — `root()` is an error (`E0049`).

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
| `root()` | Bare `root` — it's a keyword, not a call (`E0049`) |
| `root flow spawn W()` | `flow root spawn W()` — `flow` comes first |
| `w = wait f; w.field` | `w = (wait f) as W;` — else `E1032` |
| Two `can x with A entry` / `can x with B entry` | Give each ability a unique name (`E0076`) |
| Collecting results after `visit` in the same ability | `visit` is deferred — collect in a later collector node |
| `pass;` | Not supported (`E0010`) — leave the block empty |
| `lambda e: object -> None { ... }` | `lambda (e: ChangeEvent) { ... }` — params are parenthesized and typed |
| `lambda -> None { ... }` | `lambda { ... }` for a no-arg handler |
| Client `props: dict` + `props["onX"]` | Named typed params: `onX: Callable[[ChangeEvent], None]` (`E1101`) |
| `[plugins.byllm]` in jac.toml | Top-level `[byllm.model]` — `[plugins.*]` no longer parses |
