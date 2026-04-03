"""Hackathon Pitch Builder — server logic + client entry.

Follow-along mode:  jac run step1_generate.jac   (and step2, step3, step4)
Full app mode:      jac start app.jac
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
#
# Combines two agentic primitives:
#   Route  — `visit [-->] by llm()` reads node descriptions, picks the right experts
#   Spawn  — each visited node launches a parallel AdviceWorker (flow spawn)
#
# The walker routes first, launching all workers concurrently, then awaits them all.

# Standalone advise functions — one per mentor type
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

# Worker walker — runs concurrently, one per selected mentor
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

# Expert nodes — LLM reads `description` to decide which ones to visit
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

node CollectNode {}   # walker walks here after all mentor visits to await workers

walker HackathonAdvisor {
    has pitch: str;
    has tasks: list = [];    # flow spawn handles (awaited with `wait`)
    has mentors: list = [];  # parallel list: mentor name per task
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
        # Route: LLM reads each node's `description`, visits the best matches.
        # Each visited node flow-spawns an AdviceWorker — all run in parallel.
        visit [-->] by llm(incl_info={"Hackathon pitch": self.pitch});
        visit collect;
    }

    can collect with CollectNode entry {
        # All mentor visits done — await each parallel worker and collect results
        for i in range(len(self.tasks)) {
            w = wait self.tasks[i];
            self.results = self.results + [{"mentor": self.mentors[i], "advice": w.advice}];
        }
    }
}

# ── Public server functions (called from frontend via sv import) ───────────────

def:pub run_brainstorm(interests: str, skills: str) -> dict {
    return {"ideas": brainstorm_ideas(interests, skills)};
}

def:pub run_structure(raw_idea: str, interests: str, skills: str) -> dict {
    context = f"{raw_idea}\n\nBuilder background — interests: {interests}, skills: {skills}" if interests or skills else raw_idea;
    p = structure_pitch(context);
    return {
        "title": p.title,
        "problem": p.problem,
        "solution": p.solution,
        "tech_stack": p.tech_stack,
        "wow_factor": p.wow_factor,
        "difficulty": str(p.difficulty),
        "track": str(p.track)
    };
}

def:pub run_research(idea: str, title: str, solution: str) -> dict {
    query = idea if idea else f"{title}: {solution}";
    return {"research": research_idea(query)};
}

def:pub run_route(title: str, problem: str, solution: str, tech_stack: list, wow_factor: str, research: str) -> dict {
    # Build a rich context string so mentors give specific, not generic, advice
    pitch = f"""Project: {title}

Problem: {problem}

Solution: {solution}

Tech stack: {", ".join(tech_stack)}

Wow factor: {wow_factor}

Research findings:
{research}""";
    advisor = root() spawn HackathonAdvisor(pitch=pitch);
    return {"results": advisor.results};
}

# ── Client entry ───────────────────────────────────────────────────────────────

cl {
    import "./frontend/styles.css";
    import from frontend.App { App }

    def:pub app() -> JsxElement {
        return <App />;
    }
}
