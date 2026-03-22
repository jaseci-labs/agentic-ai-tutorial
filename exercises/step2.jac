"""Exercise 2: Extract — Mind primitive.
The return type constrains what the LLM can produce.
The compiler enforces the schema — no more 'parse and pray.'

Primitive: Extract (LLM -> typed data)

YOUR TASK:
  Define a function `classify_paper` that returns a typed PaperClassification
  object. The LLM must conform to the schema below.

HINT: Look at solutions/step2_extract.jac if you get stuck.
"""

import from tools { save_md }

# These types are provided — the LLM's output MUST conform to this schema.
enum Topic { HARDWARE, SOFTWARE, NETWORKS, AI, OTHER }

obj PaperClassification {
    has topic: Topic;
    has one_line_summary: str;
    has key_contributions: list[str];
}

# TODO: Define a `classify_paper` function that:
#   - Takes title (str) and abstract (str) as inputs
#   - Returns a PaperClassification (not str — a typed object!)
#   - Delegates to the LLM using `by llm()`
#
# Then add a semantic hint:
#   sem classify_paper = "Classify a research paper by its title and abstract.";



with entry {
    result = classify_paper(
        title="Attention Is All You Need",
        abstract="""
                The dominant sequence transduction models are based on complex recurrent or convolutional neural networks in an encoder-decoder configuration.
                The best performing models also connect the encoder and decoder through an attention mechanism.
                We propose a new simple network architecture, the Transformer, based solely on attention mechanisms, dispensing with recurrence and convolutions entirely.
                Experiments on two machine translation tasks show these models to be superior in quality while being more parallelizable and requiring significantly less time to train.
                Our model achieves 28.4 BLEU on the WMT 2014 English-to-German translation task, improving over the existing best results, including ensembles by over 2 BLEU.
                On the WMT 2014 English-to-French translation task, our model establishes a new single-model state-of-the-art BLEU score of 41.8 after training for 3.5 days on eight GPUs,
                a small fraction of the training costs of the best models from the literature. We show that the Transformer generalizes well to other tasks by applying it successfully to
                English constituency parsing both with large and limited training data.
                """
    );
    print(f"Topic: {result.topic}");
    print(f"Summary: {result.one_line_summary}");
    print("Key Contributions:");
    for (idx, contribution) in enumerate(result.key_contributions) {
        print(f"{idx + 1}. {contribution}");
    }

    # Save output as markdown
    contribs = "\n".join([f"- {c}" for c in result.key_contributions]);
    md = f"# Step 2: Extract\n\n## Paper: Attention Is All You Need\n\n| Field | Value |\n|-------|-------|\n| **Topic** | {result.topic} |\n| **Summary** | {result.one_line_summary} |\n\n## Key Contributions\n{contribs}\n";
    save_md("step2_extract.md", md);
}
