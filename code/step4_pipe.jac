"""Step 4: Pipe — Flow primitive.
The output of one operation feeds as input to the next.
No branching, no looping, no parallelism — just a chain
of sequential transformations. Pipe is the simplest way
to compose multiple Mind primitives into a workflow.

Primitive: Pipe (sequential task flow)
Builds on: Generate (Step 1)"""

def draft_explanation(topic: str) -> str by llm();
def add_examples(explanation: str) -> str by llm();
def write_summary(detailed_text: str) -> str by llm();

sem draft_explanation = "Write a detailed technical explanation suitable for a conference tutorial.";
sem add_examples = "Enhance a technical explanation by adding concrete, illustrative examples.";
sem write_summary = "Condense a detailed explanation into a concise 2-3 sentence summary.";

with entry {
    # Pipe: each Generate's output flows into the next as input.
    # draft → enrich → condense

    raw = draft_explanation("How cache coherence protocols work in multicore processors");
    print("=== Draft ===");
    print(raw);

    enriched = add_examples(raw);
    print("\n=== With Examples ===");
    print(enriched);

    summary = write_summary(enriched);
    print("\n=== Summary ===");
    print(summary);
}
