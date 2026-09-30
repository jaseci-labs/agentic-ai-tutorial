"""Main app component — owns all state and server calls.
Imported by app.jac's client entry.

State flows downward through props; async handlers live here.
Each step unlocks when the previous one completes.
"""

import from ..app { run_brainstorm, run_structure, run_research, run_route }
# run_route args: title, problem, solution, tech_stack, wow_factor, research

import from Step1 { Step1 }
import from Step2 { Step2 }
import from Step3 { Step3 }
import from Step4 { Step4 }
import from AgentChat { AgentChat }

# Header chips, one per pattern. Whole class strings, so Tailwind can see them.
glob PATTERNS: list[dict[str, str]] = [
    {"label": "1 · Generate", "cls": "border-gen/30 bg-gen/10 text-gen"},
    {"label": "2 · Extract", "cls": "border-ext/30 bg-ext/10 text-ext"},
    {"label": "3 · Invoke", "cls": "border-inv/30 bg-inv/10 text-inv"},
    {"label": "4 · Route", "cls": "border-rte/30 bg-rte/10 text-rte"}
];

glob TAB: str = "flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition ";

glob TAB_ON: str = "bg-panel-2 text-fg shadow-sm";

glob TAB_OFF: str = "text-dim hover:text-fg";

def:pub App() -> JsxElement {
    # "build" = the four guided steps; "agent" = the streaming chat agent
    has tab: str = "build";

    # ── Step 1 state ─────────────────────────────────────────────────────────
    has interests: str = "";
    has skills: str = "";
    has ideas: str = "";

    # ── Step 2 state ─────────────────────────────────────────────────────────
    has raw_idea: str = "";
    has pitch: dict[str, any] = {};

    # ── Step 3 state ─────────────────────────────────────────────────────────
    has research_query: str = "";
    has research: str = "";

    # ── Step 4 state ─────────────────────────────────────────────────────────
    has pitch_summary: str = "";
    has mentor_results: list[any] = [];

    # ── Progress tracking ─────────────────────────────────────────────────────
    has completed: int = 0;   # highest completed step (0 = none)
    has loading_step: int = 0;
    has errors: dict[str, any] = {};

    can with entry {
        document.title = "Hackathon Pitch Builder";
    }

    # ── Step 1: Generate ─────────────────────────────────────────────────────
    async def do_brainstorm() -> None {
        if not interests or not skills { return; }
        loading_step = 1;
        errors = {};
        try {
            result = root spawn run_brainstorm(interests=interests, skills=skills);
            ideas = result.reports[0];
            raw_idea = ideas;           # pre-fill step 2 input
            completed = 1;
        } except Exception as e {
            errors = {"1": str(e)};
        }
        loading_step = 0;
    }

    # ── Step 2: Extract ───────────────────────────────────────────────────────
    async def do_structure() -> None {
        if not raw_idea { return; }
        loading_step = 2;
        errors = {};
        try {
            result = root spawn run_structure(raw_idea=raw_idea, interests=interests, skills=skills);
            pitch = result.reports[0];
            # Pre-fill downstream steps from structured pitch
            research_query = str(pitch["title"] or "") + " — " + str(pitch["solution"] or "");
            pitch_summary = (
                str(pitch["title"] or "") + ". " +
                str(pitch["solution"] or "") + ". " +
                str(pitch["wow_factor"] or "")
            ).strip();
            completed = 2;
        } except Exception as e {
            errors = {"2": str(e)};
        }
        loading_step = 0;
    }

    # ── Step 3: Invoke ────────────────────────────────────────────────────────
    async def do_research() -> None {
        if not research_query { return; }
        loading_step = 3;
        errors = {};
        try {
            result = root spawn run_research(
                idea=research_query,
                title=str(pitch["title"] or ""),
                solution=str(pitch["solution"] or "")
            );
            research = result.reports[0];
            completed = 3;
        } except Exception as e {
            errors = {"3": str(e)};
        }
        loading_step = 0;
    }

    # ── Step 4: Route ─────────────────────────────────────────────────────────
    async def do_route() -> None {
        if not pitch { return; }
        loading_step = 4;
        errors = {};
        try {
            result = root spawn run_route(
                title=str(pitch["title"] or ""),
                problem=str(pitch["problem"] or ""),
                solution=str(pitch["solution"] or ""),
                tech_stack=pitch["tech_stack"] or [],
                wow_factor=str(pitch["wow_factor"] or ""),
                research=research
            );
            mentor_results = result.reports[0];
            completed = 4;
        } except Exception as e {
            errors = {"4": str(e)};
        }
        loading_step = 0;
    }

    # ── Render ────────────────────────────────────────────────────────────────
    return <div className={"mx-auto px-4 pb-20 sm:px-6 " + ("max-w-7xl" if tab == "agent" else "max-w-3xl")}>
        <header className="pt-14 pb-8 text-center">
            <div className="inline-flex items-center gap-2 rounded-full border border-line bg-panel/70 px-3 py-1 text-xs font-medium text-dim">
                <span className="size-1.5 rounded-full bg-gen"></span>
                JacHacks · Agentic AI Workshop
            </div>
            <h1 className="mt-5 bg-linear-to-r from-gen via-fuchsia-300 to-ext bg-clip-text text-4xl font-semibold tracking-tight text-transparent sm:text-5xl">
                Hackathon Pitch Builder
            </h1>
            <p className="mt-3 text-base text-dim">Build your project pitch with 4 agentic AI patterns</p>
            <div className="mt-6 flex flex-wrap justify-center gap-2">
                {[
                    <span key={p["label"]} className={"rounded-full border px-3 py-1 text-xs font-medium " + p["cls"]}>{p["label"]}</span>
                    for p in PATTERNS
                ]}
            </div>
        </header>

        <nav className="mb-10 flex justify-center">
            <div className="inline-flex rounded-xl border border-line bg-panel p-1">
                <button className={TAB + (TAB_ON if tab == "build" else TAB_OFF)} onClick={lambda { tab = "build"; }}>
                    Guided build
                </button>
                <button className={TAB + (TAB_ON if tab == "agent" else TAB_OFF)} onClick={lambda { tab = "agent"; }}>
                    Agent chat
                    <span className="flex items-center gap-1 rounded-full bg-ok/10 px-1.5 py-0.5 text-[10px] font-semibold tracking-wide text-ok uppercase">
                        <span className="size-1 animate-pulse rounded-full bg-ok"></span>
                        streaming
                    </span>
                </button>
            </div>
        </nav>

        {if tab == "agent" { <AgentChat /> }}

        {if tab == "build" {
            <Step1
                interests={interests}
                skills={skills}
                ideas={ideas}
                loading={loading_step == 1}
                error={errors["1"] or ""}
                isDone={completed >= 1}
                isLocked={False}
                onInterestsChange={lambda (e: ChangeEvent) { interests = e.target.value; }}
                onSkillsChange={lambda (e: ChangeEvent) { skills = e.target.value; }}
                onSubmit={lambda { do_brainstorm(); }}
            />

            <Step2
                rawIdea={raw_idea}
                pitch={pitch}
                loading={loading_step == 2}
                error={errors["2"] or ""}
                isDone={completed >= 2}
                isLocked={completed < 1}
                onRawIdeaChange={lambda (e: ChangeEvent) { raw_idea = e.target.value; }}
                onSubmit={lambda { do_structure(); }}
                onCopyToStep3={lambda { research_query = (pitch["title"] or "") + ": " + (pitch["solution"] or "") + ". " + (pitch["wow_factor"] or ""); }}
            />

            <Step3
                idea={research_query}
                research={research}
                loading={loading_step == 3}
                error={errors["3"] or ""}
                isDone={completed >= 3}
                isLocked={completed < 2}
                onIdeaChange={lambda (e: ChangeEvent) { research_query = e.target.value; }}
                onSubmit={lambda { do_research(); }}
            />

            <Step4
                pitch={pitch_summary}
                mentorResults={mentor_results}
                loading={loading_step == 4}
                error={errors["4"] or ""}
                isDone={completed >= 4}
                isLocked={completed < 2}
                onSubmit={lambda { do_route(); }}
            />
        }}

        <footer className="mt-10 text-center text-xs text-faint">Built with Jac · jachacks.org</footer>
    </div>;
}
