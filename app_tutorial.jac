"""Hackathon Pitch Builder — TUTORIAL TEMPLATE.

The four mind/flow primitives (brainstorm_ideas, structure_pitch, research_idea,
HackathonAdvisor) are already wired up below. Your job is to expose each one as
a `walker:pub` HTTP endpoint so the React frontend can call it.

Look for the four `TODO` blocks at the bottom of the file. Each one tells you:
  • what `has` input fields the walker needs (matches what the frontend sends)
  • which underlying primitive to call
  • what to `report` back

When all four walkers are filled in:
    jac start app_tutorial.jac
    open http://localhost:8000
"""

import from tools { search_github, describe_tech_stack, estimate_build_time }
import from jac_mcp.tools { search_docs, get_example, understand_jac_and_jaseci }

# ── Mind primitives (Steps 1–3) ────────────────────────────────────────────────

def brainstorm_ideas(interests: str, skills: str) -> str by llm();
sem brainstorm_ideas = "Brainstorm 3 creative hackathon project ideas based on the person's interests and skills. For each idea give it a catchy name and a one-sentence description. Make them fun, feasible in 24 hours, and genuinely useful.";

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

def structure_pitch(raw_idea: str) -> HackathonPitch by llm();
sem structure_pitch = "Turn a raw hackathon idea into a structured, compelling pitch with a title, problem statement, solution, tech stack, wow factor, difficulty, and track.";

def research_idea(idea: str) -> str by llm(
    tools=[search_github, describe_tech_stack, estimate_build_time]
);
sem research_idea = "Research a hackathon project idea: find similar open-source projects on GitHub, recommend the right tech stack, and give an honest estimate of whether it's buildable in 24-48 hours with a small team.";

# ── Flow primitive (Route — Step 4) — expert mentor graph ─────────────────────

def advise_web(pitch: str) -> str by llm();
def advise_mobile(pitch: str) -> str by llm();
def advise_aiml(pitch: str) -> str by llm();
def advise_game(pitch: str) -> str by llm();
def advise_jac(pitch: str) -> str by llm(
    tools=[search_docs, get_example],
    incl_info={"jaseci_knowledge": understand_jac_and_jaseci()}
);

sem advise_web = "Give practical next-step advice for building this web app at a hackathon. Suggest concrete first tasks, tools, and APIs.";
sem advise_mobile = "Give practical next-step advice for building this mobile app at a hackathon. Suggest concrete first tasks, frameworks, and libraries.";
sem advise_aiml = "Give practical next-step advice for integrating AI/ML into this hackathon project. Suggest model APIs, embeddings, or pipelines to use.";
sem advise_game = "Give practical next-step advice for building this game at a hackathon. Suggest engines, mechanics, and first implementation steps.";
sem advise_jac = "Give practical next-step advice for building this project using Jac and Jaseci. Use the search_docs and get_example tools to pull relevant documentation and code examples.";

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

walker HackathonAdvisor {
    has pitch: str;
    has tasks: list = [];
    has mentors: list = [];
    has results: list = [];

    can route with Root entry {
        web  = WebDevMentor();
        mob  = MobileMentor();
        aiml = AIMLMentor();
        game = GameDevMentor();
        jac  = JacExpert();
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
        visit [-->] by llm(incl_info={"Hackathon pitch": self.pitch});
        visit collect;
    }

    can collect with CollectNode entry {
        for i in range(len(self.tasks)) {
            w = wait self.tasks[i];
            self.results = self.results + [{"mentor": self.mentors[i], "advice": w.advice}];
        }
    }
}

# ── 🛠️  PUBLIC ENDPOINTS — YOUR TURN ──────────────────────────────────────────
#
# Each `walker:pub` below becomes a POST endpoint automatically when you run
# `jac start app_tutorial.jac`. The frontend calls them via:
#
#     result = root() spawn walker_name(field=value, ...);
#     value  = result.reports[0];
#
# Walker recipe:
#     walker:pub WalkerName {
#         has field1: type;            # ← request body fields
#         has field2: type;
#         can do with Root entry {     # ← runs when client spawns it from root
#             report some_value;       # ← becomes result.reports[0] on the client
#         }
#     }
# ──────────────────────────────────────────────────────────────────────────────

# TODO 1 — Step 1 (Generate): brainstorm ideas
# Frontend sends:  interests (str), skills (str)
# You should:     call `brainstorm_ideas(interests, skills)` and `report` the string
walker:pub run_brainstorm {
    # has ...
    # can do with Root entry { ... }
}

# TODO 2 — Step 2 (Extract): turn raw idea text into a typed HackathonPitch
# Frontend sends:  raw_idea (str), interests (str), skills (str)
# You should:     optionally append the builder background to raw_idea,
#                 call `structure_pitch(...)`, and `report` the HackathonPitch
walker:pub run_structure {
    # has ...
    # can do with Root entry { ... }
}

# TODO 3 — Step 3 (Invoke): research the idea using tools
# Frontend sends:  idea (str), title (str), solution (str)
# You should:     build a query string (prefer `idea`, fall back to title+solution),
#                 call `research_idea(query)`, and `report` the result string
walker:pub run_research {
    # has ...
    # can do with Root entry { ... }
}

# TODO 4 — Step 4 (Route): spawn HackathonAdvisor and report mentor advice
# Frontend sends:  title, problem, solution, tech_stack (list), wow_factor, research
# You should:     build a rich `pitch` string from those fields,
#                 spawn `HackathonAdvisor(pitch=pitch)` from root,
#                 and `report` the advisor's `results`
walker:pub run_route {
    # has ...
    # can do with Root entry { ... }
}

# ── Client entry ───────────────────────────────────────────────────────────────

cl {
    import "./frontend/styles.css";
    import from frontend.App { App }

    def:pub app() -> JsxElement {
        return <App />;
    }
}
