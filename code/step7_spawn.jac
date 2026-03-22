"""Step 7: Spawn — Flow primitive.
Dispatch multiple walkers simultaneously, each with its own
scoped tools and context. Merge their results.
Spawn enables parallel execution: split work → run concurrently → synthesize.

Primitive: Spawn (parallelize work and aggregate results)
Builds on: Generate (Step 1), Invoke (Step 3)"""

import from tools { search_papers, get_citations }

# --- Specialized research walkers ---
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

        # Spawn: launch all three researchers concurrently
        print("Spawning parallel researchers...");
        hw_task = flow root spawn HardwareResearcher(topic=self.topic);
        sw_task = flow root spawn SoftwareResearcher(topic=self.topic);
        ai_task = flow root spawn AIResearcher(topic=self.topic);

        # Wait for all to complete
        hw = wait hw_task;
        sw = wait sw_task;
        ai = wait ai_task;

        print(f"\n--- Hardware Findings ---\n{hw.result}");
        print(f"\n--- Software Findings ---\n{sw.result}");
        print(f"\n--- AI Findings ---\n{ai.result}");

        # Generate: synthesize all findings
        self.response = self.synthesize(self.topic, hw.result, sw.result, ai.result);
        print(f"\n=== Unified Survey ===\n{self.response}");
    }
}

sem SurveyAgent.synthesize = "Synthesize findings from hardware, software, and AI research into a unified survey-style summary.";

with entry {
    result = root spawn SurveyAgent(
        topic="Efficient inference for large language models"
    );
}
