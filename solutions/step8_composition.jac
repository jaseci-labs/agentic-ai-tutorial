"""Step 8: Full Composition — All 7 primitives in one system.
A self-correcting parallel research agent that:
  1. Routes to relevant research tracks       (Route)
  2. Spawns researchers with scoped tools     (Spawn + Invoke)
  3. Synthesizes findings sequentially        (Pipe + Generate)
  4. Self-critiques and revises               (Loop + Extract)

Primitives used: Pipe, Route, Loop, Spawn, Generate, Extract, Invoke
Builds on: All previous steps"""

import from tools { search_papers, get_citations, save_md }
import from byllm.lib { Model }

glob llm = Model("gpt-4o", config={"verbose": True});

# ===== Typed evaluation schema (Extract) =====
enum Verdict { PUBLISH_READY, NEEDS_REVISION }

obj SurveyReview {
    has verdict: Verdict;
    has coverage_gaps: list[str];
    has suggestions: list[str];
}

# ===== Specialized research walkers (Spawn + Invoke) =====
# Each walker runs independently with its own scoped tools.
walker HWResearcher {
    has topic: str;
    has result: str = "";

    def investigate(topic: str) -> str by llm(tools=[search_papers, get_citations]);
    can start with Root entry {
        self.result = self.investigate(self.topic);
    }
}

walker SysResearcher {
    has topic: str;
    has result: str = "";

    def investigate(topic: str) -> str by llm(tools=[search_papers, get_citations]);
    can start with Root entry {
        self.result = self.investigate(self.topic);
    }
}

walker MLResearcher {
    has topic: str;
    has result: str = "";

    def investigate(topic: str) -> str by llm(tools=[search_papers, get_citations]);
    can start with Root entry {
        self.result = self.investigate(self.topic);
    }
}

sem HWResearcher.investigate = "Research hardware architecture aspects: cache, memory, accelerators, PIM.";
sem SysResearcher.investigate = "Research systems software aspects: OS, compilers, runtime, scheduling.";
sem MLResearcher.investigate = "Research ML algorithm aspects: training, inference, model architecture.";

# ===== Track nodes — Route candidates =====
# The LLM reads these descriptions to decide which tracks are relevant.
# Only relevant tracks get visited — this is Route, not hardcoded dispatch.
node HardwareTrack {
    has description: str = "Hardware architecture track: cache, memory, accelerators, PIM";
}

node SystemsTrack {
    has description: str = "Systems software track: OS, compilers, runtime, scheduling";
}

node MLTrack {
    has description: str = "ML algorithms track: training, inference, model architecture";
}

# ===== Synthesis node — downstream of tracks =====
# The walker reaches this node by walking forward from selected tracks.
node SynthesisNode {}

# ===== Main orchestrator walker =====
walker SurveyOrchestrator {
    has topic: str;
    has tasks: list = [];
    has survey: str = "";
    has max_revisions: int = 2;
    has synthesis_started: bool = False;

    def write_survey(topic: str, findings: list[str]) -> str by llm();
    def review_survey(survey: str, topic: str) -> SurveyReview by llm();
    def revise_survey(survey: str, feedback: str) -> str by llm();
    # --- Phase 1: Route — LLM picks relevant tracks ---
    # The LLM reads each track node's description and selects
    # only the ones relevant to the research topic.
    can route with Root entry {
        print(f"=== Survey Agent: {self.topic} ===\n");
        print("[Phase 1] Routing to relevant tracks...\n");
        visit [-->] by llm(incl_info={"Research topic": self.topic});
    }

    # --- Phase 2: Spawn — launch researcher at each selected track ---
    # At each track the LLM selected, spawn a researcher asynchronously.
    # flow spawn returns immediately — researchers run in parallel.
    # Then walk forward to SynthesisNode.
    can research with HardwareTrack entry {
        print("  [Route -> Hardware] Selected by LLM");
        task = flow root spawn HWResearcher(topic=self.topic) ;
        self.tasks.append(task);
        visit [-->];
    }

    can research with SystemsTrack entry {
        print("  [Route -> Systems] Selected by LLM");
        task = flow root spawn SysResearcher(topic=self.topic) ;
        self.tasks.append(task);
        visit [-->];
    }

    can research with MLTrack entry {
        print("  [Route -> ML] Selected by LLM");
        task = flow root spawn MLResearcher(topic=self.topic) ;
        self.tasks.append(task);
        visit [-->];
    }

    # --- Phase 3 & 4: Pipe (synthesize) + Loop (review) ---
    # All selected tracks walk forward here. The guard ensures
    # synthesis runs exactly once after all researchers are spawned.
    can synthesize with SynthesisNode entry {
        if not self.synthesis_started {
            self.synthesis_started = True;

            # Wait for all spawned researchers
            print("\n[Phase 2] Waiting for researchers...");
            findings: list[str] = [];
            for task in self.tasks {
                result = wait task ;
                findings.append(result.result);
                print(f"  Researcher done.");
            }

            # Pipe + Generate: write survey from findings
            print("\n[Phase 3] Synthesizing survey...");
            self.survey = self.write_survey(self.topic, findings);

            # Loop + Extract: review and revise cycle
            print("\n[Phase 4] Review cycle...");
            revision = 0;
            while revision < self.max_revisions {
                revision += 1;
                print(f"\n  [Review Round {revision}]");

                # Extract: typed evaluation with structured verdict
                review = self.review_survey(self.survey, self.topic);
                print(f"  Verdict: {review.verdict}");
                print(f"  Gaps: {review.coverage_gaps}");

                if review.verdict == Verdict.PUBLISH_READY {
                    print("  Survey approved!");
                    break;
                }

                # Generate: revise based on structured feedback
                feedback = f"Gaps: {review.coverage_gaps}. Suggestions: {review.suggestions}";
                self.survey = self.revise_survey(self.survey, feedback);
                print(f"  Revised (v{revision + 1})");
            }
        }
    }
}

sem SurveyOrchestrator.write_survey = "Synthesize research findings into a unified technical survey suitable for a conference tutorial.";
sem SurveyOrchestrator.review_survey = "Critically review a technical survey for completeness, accuracy, and suitability for a tutorial audience.";
sem SurveyOrchestrator.revise_survey = "Revise a technical survey based on reviewer feedback, addressing specific gaps and incorporating suggestions.";

# ===== Graph construction =====
# Track nodes are children of Root — these are the Route candidates.
# SynthesisNode is downstream of tracks — reached by walking forward.
# The graph topology encodes both the routing table and the data flow.
with entry {
    hw_node = HardwareTrack();
    sys_node = SystemsTrack();
    ml_node = MLTrack();
    synth_node = SynthesisNode();

    # Route candidates: Root -> tracks
    root ++> hw_node;
    root ++> sys_node;
    root ++> ml_node;

    # Pipe: tracks -> synthesis (walker flows forward after spawning)
    hw_node ++> synth_node;
    sys_node ++> synth_node;
    ml_node ++> synth_node;

    result = root spawn SurveyOrchestrator(
        topic="Hardware-software co-design for efficient LLM inference"
    );

    print(f"\n{'=' * 60}");
    print("FINAL SURVEY");
    print(f"{'=' * 60}");
    print(result.survey);

    save_md("step8_composition.md", f"# Step 8: Full Composition\n\n## Topic\nHardware-software co-design for efficient LLM inference\n\n## Survey\n{result.survey}\n");
}
