"""Step 4: Route + Spawn — Flow Primitives
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Two primitives working together:

  Route  — `visit [-->] by llm()` reads each node's `description` and picks
            the best expert(s). No if/else. The graph topology IS the routing table.

  Spawn  — each visited node launches a parallel AdviceWorker (flow spawn).
            All LLM calls run concurrently. Walker awaits them after routing.

Key detail: `visit` is DEFERRED. Node abilities run only after the current
ability returns — so a walker cannot route and collect in the same ability.
Queue a collector node last, and gather the results when you arrive there.

Pattern:
    node ExpertA {
        has description: str = "What this expert knows";

        can respond with MyWalker entry {
            visitor.workers = visitor.workers + [
                flow root spawn WorkerA(query=visitor.query)
            ];
        }
    }

    node Collect {}

    walker MyWalker {
        has query: str;
        has workers: list = [];   # futures from `flow root spawn`
        has results: list = [];

        can route with Root entry {
            # LLM picks which nodes to visit based on their descriptions
            visit [-->] by llm(incl_info={"query": self.query});
            visit collect;   # queued last -> runs after every expert
        }

        can gather with Collect entry {
            # `wait` each future to get its finished walker
            for f in self.workers {
                w = (wait f) as WorkerA;
                self.results = self.results + [{"expert": w.name, "answer": w.answer}];
            }
        }
    }
"""

import from tools { save_md, search_github }

# ── Standalone advise functions ────────────────────────────────────────────────

def advise_web(pitch: str) -> str by llm();
def advise_mobile(pitch: str) -> str by llm();
def advise_aiml(pitch: str) -> str by llm();
def advise_game(pitch: str) -> str by llm();
def advise_jac(pitch: str) -> str by llm(tools=[search_github]);

sem advise_web = "Give practical next-step advice for building this web app at a hackathon. Suggest concrete first tasks, tools, and APIs.";
sem advise_mobile = "Give practical next-step advice for building this mobile app at a hackathon. Suggest concrete first tasks, frameworks, and libraries.";
sem advise_aiml = "Give practical next-step advice for integrating AI/ML into this hackathon project. Suggest model APIs, embeddings, or pipelines to use.";
sem advise_game = "Give practical next-step advice for building this game at a hackathon. Suggest engines, mechanics, and first implementation steps.";
sem advise_jac = "Give practical next-step advice for building this project using Jac and Jaseci. Use search_github to find relevant Jac/Jaseci example projects to point the builder at.";

# ── Worker walker — one spawned per selected mentor ────────────────────────────

walker AdviceWorker {
    has pitch: str;
    has mentor: str;
    has advice: str = "";

    can work with Root entry {
        if self.mentor == "Web Dev"    { self.advice = advise_web(self.pitch); }
        elif self.mentor == "Mobile"   { self.advice = advise_mobile(self.pitch); }
        elif self.mentor == "AI/ML"    { self.advice = advise_aiml(self.pitch); }
        elif self.mentor == "Game Dev" { self.advice = advise_game(self.pitch); }
        else                           { self.advice = advise_jac(self.pitch); }
    }
}

# ── Expert nodes ───────────────────────────────────────────────────────────────

node WebDevMentor {
    has description: str = "Expert in web apps: React, APIs, databases, authentication, and full-stack deployment";

    can respond with HackathonAdvisor entry {
        w = flow root spawn AdviceWorker(pitch=visitor.pitch, mentor="Web Dev");
        visitor.workers = visitor.workers + [w];
    }
}

node MobileMentor {
    has description: str = "Expert in mobile apps: iOS, Android, React Native, Expo, and mobile UX design";

    can respond with HackathonAdvisor entry {
        w = flow root spawn AdviceWorker(pitch=visitor.pitch, mentor="Mobile");
        visitor.workers = visitor.workers + [w];
    }
}

node AIMLMentor {
    has description: str = "Expert in AI/ML: LLMs, embeddings, computer vision, speech, and model APIs like OpenAI and HuggingFace";

    can respond with HackathonAdvisor entry {
        w = flow root spawn AdviceWorker(pitch=visitor.pitch, mentor="AI/ML");
        visitor.workers = visitor.workers + [w];
    }
}

node GameDevMentor {
    has description: str = "Expert in game development: Unity, Godot, Pygame, game design, and interactive experiences";

    can respond with HackathonAdvisor entry {
        w = flow root spawn AdviceWorker(pitch=visitor.pitch, mentor="Game Dev");
        visitor.workers = visitor.workers + [w];
    }
}

node JacExpert {
    has description: str = "Expert in using Jac for agentic programming, graph-based workflows, full stack app development, and LLM integration";

    can respond with HackathonAdvisor entry {
        w = flow root spawn AdviceWorker(pitch=visitor.pitch, mentor="Jac Expert");
        visitor.workers = visitor.workers + [w];
    }
}

# ── Collector node ─────────────────────────────────────────────────────────────
# `visit` is DEFERRED: node abilities run only after the current ability returns.
# So the walker cannot collect results in the same ability that routes — by then
# no mentor has spawned anything yet. It queues this node last and collects here.
node CollectNode {}

# ── Router walker ──────────────────────────────────────────────────────────────

walker:pub HackathonAdvisor {
    has pitch: str;
    has workers: list = [];
    has results: list = [];

    can route with Root entry {
        web     = WebDevMentor();
        mob     = MobileMentor();
        aiml    = AIMLMentor();
        game    = GameDevMentor();
        jac     = JacExpert();
        collect = CollectNode();

        here ++> web;
        here ++> mob;
        here ++> aiml;
        here ++> game;
        here ++> jac;

        web ++> collect;
        mob ++> collect;
        aiml ++> collect;
        game ++> collect;
        jac ++> collect;

        # Route: LLM reads each node's `description`, visits the best matches.
        # Each visited node flow-spawns an AdviceWorker — all run in parallel.
        visit [-->] by llm(incl_info={"Hackathon pitch": self.pitch});
        # Queued last, so it runs after every selected mentor has spawned.
        visit collect;
    }

    can collect with CollectNode entry {
        # `wait` each future to get its finished worker walker.
        for f in self.workers {
            w = (wait f) as AdviceWorker;
            self.results = self.results + [{"mentor": w.mentor, "advice": w.advice}];
        }
    }
}

# ── Run it ─────────────────────────────────────────────────────────────────────

with entry {
    advisor = root spawn HackathonAdvisor(
        pitch="A Spotify app that detects your music mood and auto-generates "
              "a lo-fi study playlist, synced with Google Calendar exam dates. "
              "Uses Spotify API + OpenAI for mood classification."
    );

    print(f"Pitch:  {advisor.pitch}\n");
    for r in advisor.results {
        print(f"── {r['mentor']} ──\n{r['advice']}\n");
    }

    md = f"# Step 4: Route + Spawn\n\n## Pitch\n{advisor.pitch}\n\n";
    for r in advisor.results {
        md += f"## {r['mentor']} Mentor\n{r['advice']}\n\n";
    }
    save_md("step4_route.md", md);
}
