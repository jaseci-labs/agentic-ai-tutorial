"""Step 6: Loop — Flow primitive.
Generate a draft, judge it, revise if needed, repeat.
Loop combined with Extract (typed evaluation) creates
self-correcting behavior: Generate → Extract → improve → Loop.

Primitive: Loop (repeat until done)
Builds on: Generate (Step 1), Extract (Step 2)"""

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
        # Generate: create initial draft
        self.draft = self.draft_explanation(self.topic);
        print(f"=== Draft v1 ===");
        print(self.draft);

        # Loop: repeat evaluation and improvement until quality is GOOD
        while self.iterations < self.max_iterations {
            self.iterations += 1;

            # Extract: typed evaluation (Quality enum + structured feedback)
            review = self.evaluate(self.draft, self.topic);
            self.review_log.append(
                f"Round {self.iterations}: {review.quality} — {review.suggestion}"
            );

            print(f"\n--- Review Round {self.iterations} ---");
            print(f"Quality: {review.quality}");
            print(f"Strengths: {review.strengths}");
            print(f"Weaknesses: {review.weaknesses}");

            if review.quality == Quality.GOOD {
                print("\nApproved!");
                break;
            }

            # Generate: improve based on feedback
            feedback = f"Weaknesses: {review.weaknesses}. Suggestion: {review.suggestion}";
            self.draft = self.improve(self.draft, feedback);
            print(f"\n=== Draft v{self.iterations + 1} ===");
            print(self.draft);
        }

        print(f"\n=== Final ({self.iterations} revision(s)) ===");
        print(self.draft);

        report {
            "topic": self.topic,
            "final_draft": self.draft,
            "revisions": self.iterations,
            "review_log": self.review_log
        };
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
