"""Exercise 5: Route — Flow primitive.
The LLM reads node descriptions and picks the right destination.
No if/else chains. The graph topology IS the routing table.

Primitive: Route (pick one of N directions)
Builds on: Generate (Step 1)

YOUR TASK:
  Complete the walker's `route` ability so the LLM picks
  which expert node to visit based on node descriptions.

HINT: Look at solutions/step5_route.jac if you get stuck.
"""

import from tools { save_md }

node HardwareExpert {
    has description: str = "Expert in CPU architecture, GPU design, memory hierarchies, and chip fabrication";

    def answer(question: str) -> str by llm();
    can respond with ResearchAssistant entry {
        visitor.response = self.answer(visitor.query);
    }
}

sem HardwareExpert.answer = "Answer questions about CPU, GPU, memory systems, and chip design.";

node SoftwareExpert {
    has description: str = "Expert in compilers, operating systems, virtual machines, and runtime systems";

    def answer(question: str) -> str by llm();
    can respond with ResearchAssistant entry {
        visitor.response = self.answer(visitor.query);
    }
}

node AIExpert {
    has description: str = "Expert in neural networks, LLMs, and machine learning systems";

    def answer(question: str) -> str by llm();
    can respond with ResearchAssistant entry {
        visitor.response = self.answer(visitor.query);
    }
}

sem SoftwareExpert.answer = "Answer questions about compilers, operating systems, and runtime systems.";
sem AIExpert.answer = "Answer questions about neural networks, LLMs, and machine learning.";

walker ResearchAssistant {
    has query: str;
    has response: str = "";

    can route with Root entry {
        # TODO: Use `visit` to let the LLM pick which expert to route to.
        #
        # The LLM needs to:
        #   1. See the child nodes: [-->]
        #   2. Read their descriptions
        #   3. Pick the best match for self.query
        #
        # Pattern: visit [-->] by llm(incl_info={...});
        #   incl_info passes extra context to the LLM's routing decision.

        pass;  # <-- Replace this with your visit statement
    }
}

with entry {
    root ++> HardwareExpert();
    root ++> SoftwareExpert();
    root ++> AIExpert();

    assistant = root spawn ResearchAssistant(
        query="How do branch predictors work in modern CPUs?"
    );
    print(f"Query: {assistant.query}");
    print(f"Response: {assistant.response}");

    # Save output as markdown
    md = f"# Step 5: Route\n\n## Query\n{assistant.query}\n\n## Routed Response\n{assistant.response}\n";
    save_md("step5_route.md", md);
}
