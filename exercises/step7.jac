"""Exercise 7: Spawn — Flow primitive.
Dispatch multiple walkers simultaneously, each with its own
scoped tools and context. Merge their results.
Spawn enables parallel execution: split work -> run concurrently -> synthesize.

Primitive: Spawn (parallelize work and aggregate results)
Builds on: Generate (Step 1), Invoke (Step 3)

YOUR TASK:
  In the SurveyAgent walker, spawn the three researcher walkers
  in parallel using `flow`, wait for all results, then synthesize.

HINT: Look at solutions/step7_spawn.jac if you get stuck.
"""

import from tools { search_papers, get_citations, save_md }

# --- Specialized research walkers (provided) ---
walker HardwareResearcher {
    has topic: str;
    has result: str = "";

    def investigate(topic: str) -> str by llm(tools=[search_papers, get_citations]);

    can start with Root entry {
        self.result = self.investigate(self.topic);
    }
}

walker SoftwareResearcher {
    has topic: str;
    has result: str = "";

    def investigate(topic: str) -> str by llm(tools=[search_papers, get_citations]);

    can start with Root entry {
        self.result = self.investigate(self.topic);
    }
}

walker AIResearcher {
    has topic: str;
    has result: str = "";

    def investigate(topic: str) -> str by llm(tools=[search_papers, get_citations]);

    can start with Root entry {
        self.result = self.investigate(self.topic);
    }
}

sem HardwareResearcher.investigate = "Research hardware aspects: cache, memory, accelerators, chip design.";
sem SoftwareResearcher.investigate = "Research software systems aspects: compilers, OS, runtime, scheduling.";
sem AIResearcher.investigate = "Research AI and ML aspects: training, inference, model architecture.";

# --- Orchestrator ---
walker SurveyAgent {
    has topic: str;
    has response: str = "";

    def synthesize(
        topic: str, hardware_findings: str, software_findings: str, ai_findings: str
    ) -> str by llm();

    can start with Root entry {
        print(f"=== Surveying: {self.topic} ===\n");

        # TODO: Spawn all three researchers in PARALLEL using `flow`.
        #
        # Pattern:
        #   task = flow root spawn WalkerName(args...);
        #
        # 1. Spawn HardwareResearcher, SoftwareResearcher, AIResearcher
        #    Each with topic=self.topic
        #    Use `flow` to make them async (run in parallel)


        # TODO: Wait for all three to complete.
        #
        # Pattern:
        #   result = wait task;
        #
        # Then access result.result to get each researcher's findings.


        # TODO: Print each researcher's findings.


        # TODO: Synthesize all findings into a unified survey.
        #   self.response = self.synthesize(self.topic, hw.result, sw.result, ai.result);


        print(f"\n=== Unified Survey ===\n{self.response}");

        # Save output as markdown
        md = f"# Step 7: Spawn\n\n## Topic\n{self.topic}\n\n## Unified Survey\n{self.response}\n";
        save_md("step7_spawn.md", md);
    }
}

sem SurveyAgent.synthesize = "Synthesize findings from hardware, software, and AI research into a unified survey-style summary.";

with entry {
    result = root spawn SurveyAgent(
        topic="Efficient inference for large language models"
    );
}
