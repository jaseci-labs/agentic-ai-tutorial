"""Step 2 — Extract
Takes the brainstormed ideas (editable), returns a typed HackathonPitch object.
The compiler enforces the schema — no parse-and-pray.
"""

import from ui { StepCard, PrimaryButton, TypingDots, ErrorBanner, LABEL, INPUT, RESULT }

glob DIFFICULTY_BADGE: dict[str, str] = {
    "BEGINNER": "border-ok/30 bg-ok/10 text-ok",
    "INTERMEDIATE": "border-warn/30 bg-warn/10 text-warn",
    "ADVANCED": "border-bad/30 bg-bad/10 text-bad"
};

glob FIELD_LABEL: str = "text-[11px] font-semibold tracking-wider text-faint uppercase";

glob FIELD_BOX: str = "rounded-xl border border-line bg-canvas/40 p-4";

def:pub Step2(
    rawIdea: str,
    pitch: dict[str, any],
    loading: bool,
    error: str,
    isDone: bool,
    isLocked: bool,
    onRawIdeaChange: Callable[[ChangeEvent], None],
    onSubmit: Callable[[], None],
    onCopyToStep3: Callable[[], None]
) -> JsxElement {
    state = "done" if isDone else ("locked" if isLocked else "active");

    tech_stack = pitch["tech_stack"] or [];
    difficulty = str(pitch["difficulty"] or "");
    track      = str(pitch["track"] or "");

    return <StepCard
        num={2}
        accent="ext"
        title="Extract — Structure Pitch"
        subtitle="LLM returns a typed object — compiler enforces the schema"
        state={state}
        busy={loading}
    >
        {not isDone and <div>
            <label className={LABEL}>Your idea (edit or paste a new one)</label>
            <textarea
                className={INPUT + " resize-y"}
                value={rawIdea}
                onChange={onRawIdeaChange}
                placeholder="Describe your hackathon idea..."
                rows={4}
                disabled={loading}
            />
            <div className="mt-4 flex items-center gap-4">
                <PrimaryButton accent="ext" disabled={loading or not rawIdea} onClick={onSubmit}>
                    {"Structuring..." if loading else "Structure Pitch →"}
                </PrimaryButton>
                {loading and <TypingDots />}
            </div>
        </div>}

        {error and <div className="mt-4"><ErrorBanner message={error} /></div>}

        {pitch["title"] and <div className={"" if isDone else RESULT}>
            <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                    <div className={FIELD_LABEL}>Project Title</div>
                    <div className="mt-1 text-xl font-semibold tracking-tight text-fg">{pitch["title"]}</div>
                </div>
                <div className="flex flex-wrap gap-2">
                    <span className={"rounded-full border px-2.5 py-0.5 text-xs font-medium " + (DIFFICULTY_BADGE[difficulty] or "border-line text-dim")}>
                        {difficulty}
                    </span>
                    <span className="rounded-full border border-ext/30 bg-ext/10 px-2.5 py-0.5 text-xs font-medium text-ext">
                        {track}
                    </span>
                </div>
            </div>

            <div className="mt-4 grid gap-3 sm:grid-cols-2">
                <div className={FIELD_BOX}>
                    <div className={FIELD_LABEL}>Problem</div>
                    <p className="mt-1.5 text-sm leading-relaxed text-fg/90">{pitch["problem"] or ""}</p>
                </div>
                <div className={FIELD_BOX}>
                    <div className={FIELD_LABEL}>Solution</div>
                    <p className="mt-1.5 text-sm leading-relaxed text-fg/90">{pitch["solution"] or ""}</p>
                </div>
                <div className={FIELD_BOX + " sm:col-span-2"}>
                    <div className={FIELD_LABEL}>Wow Factor ✨</div>
                    <p className="mt-1.5 text-sm leading-relaxed text-fg/90">{pitch["wow_factor"] or ""}</p>
                </div>
                <div className={FIELD_BOX + " sm:col-span-2"}>
                    <div className={FIELD_LABEL}>Tech Stack</div>
                    <div className="mt-2 flex flex-wrap gap-1.5">
                        {[<span key={t} className="rounded-md border border-line bg-panel-2 px-2 py-1 font-mono text-xs text-fg/90">{t}</span> for t in tech_stack]}
                    </div>
                </div>
            </div>

            <button
                className="mt-4 rounded-lg border border-line px-3 py-1.5 text-xs font-medium text-dim transition hover:border-line-strong hover:text-fg"
                onClick={onCopyToStep3}
            >
                Use this pitch for research →
            </button>
        </div>}
    </StepCard>;
}
