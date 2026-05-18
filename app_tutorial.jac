"""Hackathon Pitch Builder — TUTORIAL TEMPLATE.

You'll build a working agentic AI app in 4 steps. Each step has two TODOs:

  (a) Functionality — declare the LLM-powered function(s) for the pattern
  (b) Endpoint     — expose it as a `walker:pub` so the React frontend can call it

The supporting infrastructure (tool functions, mentor nodes, AdviceWorker) is
already wired up. Look for the `TODO` markers below.

When all TODOs are filled in:
    jac start app_tutorial.jac
    open http://localhost:8000

Helpful patterns:
    LLM call:   def fn(arg: T) -> R by llm();
                sem fn = "instruction-style description of what the LLM should do";
    Endpoint:   walker:pub Name {
                    has field: type;
                    can do with Root entry { report value; }
                }
"""

import from tools { search_github, describe_tech_stack, estimate_build_time }
import from jac_mcp.tools { search_docs, get_example, understand_jac_and_jaseci }


# ══════════════════════════════════════════════════════════════════════════════
# STEP 1 — Generate (free-form text from the LLM)
# ══════════════════════════════════════════════════════════════════════════════

# TODO 1a — Functionality
# Declare an LLM function `brainstorm_ideas(interests: str, skills: str) -> str`
# using `by llm()`. Add a `sem brainstorm_ideas = "..."` instruction telling the
# LLM to brainstorm 3 catchy, hackathon-feasible project ideas.
#
# def brainstorm_ideas(...) -> ... by llm();
# sem brainstorm_ideas = "...";

# TODO 1b — Endpoint
# Frontend sends:  interests (str), skills (str)
# You should:      call brainstorm_ideas(interests, skills) and `report` the result
walker:pub run_brainstorm {
    # has ...
    # can do with Root entry { ... }
}


# ══════════════════════════════════════════════════════════════════════════════
# STEP 2 — Extract (typed object back from the LLM)
# ══════════════════════════════════════════════════════════════════════════════

enum Difficulty { BEGINNER, INTERMEDIATE, ADVANCED }
enum Track { WEB, MOBILE, AI_ML, GAME, OTHER }

obj HackathonPitch {
    has title: str;
    has problem: str;
    has solution: str;
    has tech_stack: list[str];
    has wow_factor: str;
    has difficulty: Difficulty;
    has track: Track;
}

# TODO 2a — Functionality
# Declare `structure_pitch(raw_idea: str) -> HackathonPitch by llm();`
# Add a `sem` telling the LLM to turn raw idea text into a structured pitch.
#
# def structure_pitch(...) -> ... by llm();
# sem structure_pitch = "...";

# TODO 2b — Endpoint
# Frontend sends:  raw_idea (str), interests (str), skills (str)
# You should:      optionally append the builder background to raw_idea,
#                  then call structure_pitch(...) and `report` the HackathonPitch
walker:pub run_structure {
    # has ...
    # can do with Root entry { ... }
}


# ══════════════════════════════════════════════════════════════════════════════
# STEP 3 — Invoke (LLM calls tools in a ReAct loop)
# ══════════════════════════════════════════════════════════════════════════════

# TODO 3a — Functionality
# Declare `research_idea(idea: str) -> str by llm(tools=[...])` giving the LLM
# access to the three tools imported above:
#   search_github, describe_tech_stack, estimate_build_time
# Add a `sem` explaining the goal: find similar projects, recommend a stack,
# and estimate buildability in 24-48 hours.
#
# def research_idea(...) -> ... by llm(tools=[...]);
# sem research_idea = "...";

# TODO 3b — Endpoint
# Frontend sends:  idea (str), title (str), solution (str)
# You should:      build a query string (prefer `idea`, fall back to title+solution),
#                  call research_idea(query), and `report` the result string
walker:pub run_research {
    # has ...
    # can do with Root entry { ... }
}


# ══════════════════════════════════════════════════════════════════════════════
# STEP 4 — Route (walker visits LLM-chosen nodes; spawn workers in parallel)
# ══════════════════════════════════════════════════════════════════════════════

# TODO 4a — Functionality: per-mentor advise functions
# Declare 5 LLM functions, each taking `pitch: str` and returning `str`:
#   advise_web, advise_mobile, advise_aiml, advise_game, advise_jac
# advise_jac additionally uses tools=[search_docs, get_example] and
# incl_info={"jaseci_knowledge": understand_jac_and_jaseci()}.
# Add a `sem` to each one describing the mentor's specialty.
#
# def advise_web(pitch: str) -> str by llm();
# def advise_mobile(pitch: str) -> str by llm();
# def advise_aiml(pitch: str) -> str by llm();
# def advise_game(pitch: str) -> str by llm();
# def advise_jac(pitch: str) -> str by llm(tools=[...], incl_info={...});
# sem advise_web    = "...";
# sem advise_mobile = "...";
# sem advise_aiml   = "...";
# sem advise_game   = "...";
# sem advise_jac    = "...";

# ── Supporting infrastructure (already wired) ────────────────────────────────
# AdviceWorker runs one mentor's advise_* function in parallel.
# Each mentor node flow-spawns an AdviceWorker when visited.

walker AdviceWorker {
    has pitch: str;
    has mentor: str;
    has advice: str = "";

    can work with Root entry {
        # Uncomment once you've declared the advise_* functions in TODO 4a:
        # if self.mentor == "Web Dev"    { self.advice = advise_web(self.pitch); }
        # elif self.mentor == "Mobile"   { self.advice = advise_mobile(self.pitch); }
        # elif self.mentor == "AI/ML"    { self.advice = advise_aiml(self.pitch); }
        # elif self.mentor == "Game Dev" { self.advice = advise_game(self.pitch); }
        # else                           { self.advice = advise_jac(self.pitch); }
    }
}

node WebDevMentor {
    has description: str = "Expert in web apps: React, APIs, databases, authentication, and full-stack deployment";

    can respond with HackathonAdvisor entry {
        t = flow root spawn AdviceWorker(pitch=visitor.pitch, mentor="Web Dev");
        visitor.tasks = visitor.tasks + [t];
        visitor.mentors = visitor.mentors + ["Web Dev"];
    }
}

node MobileMentor {
    has description: str = "Expert in mobile apps: iOS, Android, React Native, Expo, and mobile UX design";

    can respond with HackathonAdvisor entry {
        t = flow root spawn AdviceWorker(pitch=visitor.pitch, mentor="Mobile");
        visitor.tasks = visitor.tasks + [t];
        visitor.mentors = visitor.mentors + ["Mobile"];
    }
}

node AIMLMentor {
    has description: str = "Expert in AI/ML: LLMs, embeddings, computer vision, speech, and model APIs like OpenAI and HuggingFace";

    can respond with HackathonAdvisor entry {
        t = flow root spawn AdviceWorker(pitch=visitor.pitch, mentor="AI/ML");
        visitor.tasks = visitor.tasks + [t];
        visitor.mentors = visitor.mentors + ["AI/ML"];
    }
}

node GameDevMentor {
    has description: str = "Expert in game development: Unity, Godot, Pygame, game design, and interactive experiences";

    can respond with HackathonAdvisor entry {
        t = flow root spawn AdviceWorker(pitch=visitor.pitch, mentor="Game Dev");
        visitor.tasks = visitor.tasks + [t];
        visitor.mentors = visitor.mentors + ["Game Dev"];
    }
}

node JacExpert {
    has description: str = "Expert in using Jac for agentic programming, graph-based workflows, full stack app development, and LLM integration";

    can respond with HackathonAdvisor entry {
        t = flow root spawn AdviceWorker(pitch=visitor.pitch, mentor="Jac Expert");
        visitor.tasks = visitor.tasks + [t];
        visitor.mentors = visitor.mentors + ["Jac Expert"];
    }
}

node CollectNode {}

# TODO 4b — Functionality: HackathonAdvisor walker
# Fill in the two abilities:
#   `can route with Root entry` — create one node of each mentor type + a
#     CollectNode, connect them all (here ++> mentor; mentor ++> collect),
#     then `visit [-->] by llm(incl_info={"Hackathon pitch": self.pitch});`
#     and finally `visit collect;` to gather results.
#   `can collect with CollectNode entry` — `wait` each task in self.tasks and
#     append `{"mentor": ..., "advice": w.advice}` to self.results.
walker HackathonAdvisor {
    has pitch: str;
    has tasks: list = [];
    has mentors: list = [];
    has results: list = [];

    can route with Root entry {
        # TODO 4b: build the mentor graph and visit [-->] by llm(...)
    }

    can collect with CollectNode entry {
        # TODO 4b: await each flow-spawned task and append to self.results
    }
}

# TODO 4c — Endpoint
# Frontend sends:  title, problem, solution, tech_stack (list), wow_factor, research
# You should:      build a rich `pitch` string from those fields,
#                  spawn HackathonAdvisor(pitch=pitch) from root,
#                  and `report` advisor.results
walker:pub run_route {
    # has ...
    # can do with Root entry { ... }
}


# ══════════════════════════════════════════════════════════════════════════════
# Client entry — already wired
# ══════════════════════════════════════════════════════════════════════════════

cl {
    import "./frontend/styles.css";
    import from frontend.App { App }

    def:pub app() -> JsxElement {
        return <App />;
    }
}
