"""Exercise 6: Loop — Flow primitive.
Generate a draft, judge it, revise if needed, repeat.
Loop combined with Extract (typed evaluation) creates
self-correcting behavior: Generate -> Extract -> improve -> Loop.

Primitive: Loop (repeat until done)
Builds on: Generate (Step 1), Extract (Step 2)

YOUR TASK:
  Implement the self-correction loop inside the walker's `start` ability.
  Use Extract (typed Review) to evaluate quality, and loop until GOOD.

HINT: Look at solutions/step6_loop.jac if you get stuck.
"""

import from tools { save_md }

enum Quality { GOOD, NEEDS_IMPROVEMENT }

obj Review {
    has quality: Quality;
    has strengths: list[str];
    has weaknesses: list[str];
    has suggestion: str;
}

walker TutorialWriter {
    has topic: str;
    has draft: str = "";
    has iterations: int = 0;
    has max_iterations: int = 3;
    has review_log: list[str] = [];

    def draft_explanation(topic: str) -> str by llm();
    def evaluate(explanation: str, topic: str) -> Review by llm();
    def improve(explanation: str, feedback: str) -> str by llm();

    can start with Root entry {
        # Step A: Generate the initial draft (provided)
        self.draft = self.draft_explanation(self.topic);
        print(f"=== Draft v1 ===");
        print(self.draft);
        md_parts: list = [f"# Step 6: Loop\n\n## Topic\n{self.topic}\n\n## Draft v1\n{self.draft}\n"];

        # TODO: Implement the self-correction loop.
        #
        # While iterations < max_iterations:
        #   1. Increment iterations
        #   2. Extract: call self.evaluate(self.draft, self.topic) -> Review
        #      (This returns a typed Review with quality, strengths, weaknesses, suggestion)
        #   3. Log the review
        #   4. If review.quality == Quality.GOOD -> break (approved!)
        #   5. Otherwise: build feedback string from review.weaknesses and review.suggestion
        #   6. Generate: call self.improve(self.draft, feedback) to get a better draft
        #   7. Print the new draft


        print(f"\n=== Final ({self.iterations} revision(s)) ===");
        print(self.draft);

        # Save output as markdown
        md_parts.append(f"\n## Final ({self.iterations} revision(s))\n{self.draft}\n");
        save_md("step6_loop.md", "\n".join(md_parts));
    }
}

sem TutorialWriter.draft_explanation = "Write a concise technical explanation suitable for a conference tutorial audience.";
sem TutorialWriter.evaluate = "Evaluate a technical explanation for clarity, accuracy, and completeness. Be critical — only mark GOOD if truly ready for a tutorial audience.";
sem TutorialWriter.improve = "Improve a technical explanation based on specific feedback.";

with entry {
    result = root spawn TutorialWriter(
        topic="How cache coherence protocols work in multicore processors"
    );
}
