"""Exercise 4: Pipe — Flow primitive.
The output of one operation feeds as input to the next.
No branching, no looping, no parallelism — just a chain
of sequential transformations. Pipe is the simplest way
to compose multiple Mind primitives into a workflow.

Primitive: Pipe (sequential task flow)
Builds on: Generate (Step 1)

YOUR TASK:
  Define three Generate functions and chain them:
  draft_explanation -> add_examples -> write_summary.
  Each function's output becomes the next function's input.

HINT: Look at solutions/step4_pipe.jac if you get stuck.
"""

import from tools { save_md }

# TODO: Define three functions, each using `by llm()`:
#
#   1. draft_explanation(topic: str) -> str
#      sem = "Write a detailed technical explanation suitable for a conference tutorial."
#
#   2. add_examples(explanation: str) -> str
#      sem = "Enhance a technical explanation by adding concrete, illustrative examples."
#
#   3. write_summary(detailed_text: str) -> str
#      sem = "Condense a detailed explanation into a concise 2-3 sentence summary."



with entry {
    # Pipe: each Generate's output flows into the next as input.
    # draft -> enrich -> condense

    raw = draft_explanation("How cache coherence protocols work in multicore processors");
    print("=== Draft ===");
    print(raw);

    enriched = add_examples(raw);
    print("\n=== With Examples ===");
    print(enriched);

    summary = write_summary(enriched);
    print("\n=== Summary ===");
    print(summary);

    # Save output as markdown
    md = f"# Step 4: Pipe\n\n## Topic\nHow cache coherence protocols work in multicore processors\n\n## Stage 1: Draft\n{raw}\n\n## Stage 2: With Examples\n{enriched}\n\n## Stage 3: Summary\n{summary}\n";
    save_md("step4_pipe.md", md);
}
