"""Main app component — owns all state and server calls.
Imported by app.jac's cl {} block.

State flows downward through props; async handlers live here.
Each step unlocks when the previous one completes.
"""

sv import from ...app { run_brainstorm, run_structure, run_research, run_route }
# run_route args: title, problem, solution, tech_stack, wow_factor, research

import from Step1 { Step1 }
import from Step2 { Step2 }
import from Step3 { Step3 }
import from Step4 { Step4 }

def:pub App() -> JsxElement {
    # ── Step 1 state ─────────────────────────────────────────────────────────
    has interests: str = "";
    has skills: str = "";
    has ideas: str = "";

    # ── Step 2 state ─────────────────────────────────────────────────────────
    has raw_idea: str = "";
    has pitch: dict = {};

    # ── Step 3 state ─────────────────────────────────────────────────────────
    has research_query: str = "";
    has research: str = "";

    # ── Step 4 state ─────────────────────────────────────────────────────────
    has pitch_summary: str = "";
    has mentor_results: list = [];

    # ── Progress tracking ─────────────────────────────────────────────────────
    has completed: int = 0;   # highest completed step (0 = none)
    has loading_step: int = 0;
    has errors: dict = {};

    # ── Step 1: Generate ─────────────────────────────────────────────────────
    async def do_brainstorm() -> None {
        if not interests or not skills { return; }
        loading_step = 1;
        errors = {};
        try {
            result = await run_brainstorm(interests, skills);
            ideas = result["ideas"];
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
            result = await run_structure(raw_idea, interests, skills);
            pitch = result;
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
            result = await run_research(
                research_query,
                str(pitch["title"] or ""),
                str(pitch["solution"] or "")
            );
            research = result["research"];
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
            result = await run_route(
                str(pitch["title"] or ""),
                str(pitch["problem"] or ""),
                str(pitch["solution"] or ""),
                pitch["tech_stack"] or [],
                str(pitch["wow_factor"] or ""),
                research
            );
            mentor_results = list(result["results"]) if result["results"] else [];
            completed = 4;
        } except Exception as e {
            errors = {"4": str(e)};
        }
        loading_step = 0;
    }

    # ── Render ────────────────────────────────────────────────────────────────
    return <div className="app">
        <header className="header">
            <div className="header-eyebrow">JacHacks · Agentic AI Workshop</div>
            <h1>Hackathon Pitch Builder</h1>
            <p>Build your project pitch with 4 agentic AI primitives</p>
            <div className="primitives-bar">
                <span className="prim-badge s1">1 · Generate</span>
                <span className="prim-badge s2">2 · Extract</span>
                <span className="prim-badge s3">3 · Invoke</span>
                <span className="prim-badge s4">4 · Route</span>
            </div>
        </header>

        <Step1
            interests={interests}
            skills={skills}
            ideas={ideas}
            loading={loading_step == 1}
            error={errors["1"] or ""}
            isDone={completed >= 1}
            isLocked={False}
            onInterestsChange={lambda e: object -> None { interests = e.target.value; }}
            onSkillsChange={lambda e: object -> None { skills = e.target.value; }}
            onSubmit={lambda -> None { do_brainstorm(); }}
        />

        <Step2
            rawIdea={raw_idea}
            pitch={pitch}
            loading={loading_step == 2}
            error={errors["2"] or ""}
            isDone={completed >= 2}
            isLocked={completed < 1}
            onRawIdeaChange={lambda e: object -> None { raw_idea = e.target.value; }}
            onSubmit={lambda -> None { do_structure(); }}
            onCopyToStep3={lambda -> None {
                research_query = (pitch["title"] or "") + ": " + (pitch["solution"] or "") + ". " + (pitch["wow_factor"] or "");
            }}
        />

        <Step3
            idea={research_query}
            research={research}
            loading={loading_step == 3}
            error={errors["3"] or ""}
            isDone={completed >= 3}
            isLocked={completed < 2}
            onIdeaChange={lambda e: object -> None { research_query = e.target.value; }}
            onSubmit={lambda -> None { do_research(); }}
        />

        <Step4
            pitch={pitch_summary}
            mentorResults={mentor_results}
            loading={loading_step == 4}
            error={errors["4"] or ""}
            isDone={completed >= 4}
            isLocked={completed < 2}
            onSubmit={lambda -> None { do_route(); }}
        />

        <div className="footer-note">
            Built with Jac · jachacks.org
        </div>
    </div>;
}
