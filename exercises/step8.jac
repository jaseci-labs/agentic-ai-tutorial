"""Exercise 8: Full Composition — All 7 primitives in one system.
A self-correcting parallel research agent that:
  1. Routes to relevant research tracks       (Route)
  2. Spawns researchers with scoped tools     (Spawn + Invoke)
  3. Synthesizes findings sequentially        (Pipe + Generate)
  4. Self-critiques and revises               (Loop + Extract)

Primitives used: Pipe, Route, Loop, Spawn, Generate, Extract, Invoke
Builds on: All previous steps

YOUR TASK:
  Fill in the four phases of the orchestrator walker.
  Each phase uses primitives you've already practiced.

HINT: Look at solutions/step8_composition.jac if you get stuck.
"""

import from tools { search_papers, get_citations, save_md }

# ===== Typed evaluation schema (Extract) =====
enum Verdict { PUBLISH_READY, NEEDS_REVISION }

obj SurveyReview {
    has verdict: Verdict;
    has coverage_gaps: list[str];
    has suggestions: list[str];
}

# ===== Specialized research walkers (Spawn + Invoke) — provided =====
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

# ===== Track nodes — Route candidates (provided) =====
node HardwareTrack {
    has description: str = "Hardware architecture track: cache, memory, accelerators, PIM";
}

node SystemsTrack {
    has description: str = "Systems software track: OS, compilers, runtime, scheduling";
}

node MLTrack {
    has description: str = "ML algorithms track: training, inference, model architecture";
}

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
    can route with Root entry {
        print(f"=== Survey Agent: {self.topic} ===\n");
        print("[Phase 1] Routing to relevant tracks...\n");

        # TODO: Use `visit` with `by llm()` to let the LLM pick which
        #       track nodes to visit. Pass the research topic as context.
        # Pattern: visit [-->] by llm(incl_info={...});

    }

    # --- Phase 2: Spawn — launch researcher at each selected track ---
    can research with HardwareTrack entry {
        print("  [Route -> Hardware] Selected by LLM");

        # TODO: Spawn a HWResearcher using `flow root spawn ...`
        #       Append the task to self.tasks
        #       Then `visit [-->]` to continue to SynthesisNode

    }

    can research with SystemsTrack entry {
        print("  [Route -> Systems] Selected by LLM");

        # TODO: Spawn a SysResearcher, append task, visit forward

    }

    can research with MLTrack entry {
        print("  [Route -> ML] Selected by LLM");

        # TODO: Spawn a MLResearcher, append task, visit forward

    }

    # --- Phase 3 & 4: Pipe (synthesize) + Loop (review) ---
    can synthesize with SynthesisNode entry {
        if not self.synthesis_started {
            self.synthesis_started = True;

            # TODO: Wait for all spawned researchers
            # Pattern:
            #   findings: list[str] = [];
            #   for task in self.tasks { result = wait task; findings.append(result.result); }


            # TODO: Pipe + Generate: write survey from findings
            #   self.survey = self.write_survey(self.topic, findings);


            # TODO: Loop + Extract: review and revise cycle
            # Pattern:
            #   while revision < self.max_revisions:
            #     review = self.review_survey(self.survey, self.topic)
            #     if review.verdict == Verdict.PUBLISH_READY: break
            #     feedback = f"Gaps: {review.coverage_gaps}. Suggestions: {review.suggestions}"
            #     self.survey = self.revise_survey(self.survey, feedback)

        }
    }
}

sem SurveyOrchestrator.write_survey = "Synthesize research findings into a unified technical survey suitable for a conference tutorial.";
sem SurveyOrchestrator.review_survey = "Critically review a technical survey for completeness, accuracy, and suitability for a tutorial audience.";
sem SurveyOrchestrator.revise_survey = "Revise a technical survey based on reviewer feedback, addressing specific gaps and incorporating suggestions.";

# ===== Graph construction (provided) =====
with entry {
    hw_node = HardwareTrack();
    sys_node = SystemsTrack();
    ml_node = MLTrack();
    synth_node = SynthesisNode();

    root ++> hw_node;
    root ++> sys_node;
    root ++> ml_node;

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

    # Save output as markdown
    save_md("step8_composition.md", f"# Step 8: Full Composition\n\n## Topic\nHardware-software co-design for efficient LLM inference\n\n## Survey\n{result.survey}\n");
}
