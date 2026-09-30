"""Step 1 — Generate
Brainstorm form: interests + skills → free-text ideas.
Pure presentational component; App.jac owns state and calls the server.
"""

import from ui { StepCard, PrimaryButton, TypingDots, ErrorBanner, Markdown, LABEL, INPUT, RESULT }

def:pub Step1(
    interests: str,
    skills: str,
    ideas: str,
    loading: bool,
    error: str,
    isDone: bool,
    isLocked: bool,
    onInterestsChange: Callable[[ChangeEvent], None],
    onSkillsChange: Callable[[ChangeEvent], None],
    onSubmit: Callable[[], None]
) -> JsxElement {
    state = "done" if isDone else ("locked" if isLocked else "active");

    return <StepCard
        num={1}
        accent="gen"
        title="Generate — Brainstorm"
        subtitle="LLM returns free text from a function signature"
        state={state}
        busy={loading}
    >
        <div className="grid gap-4 sm:grid-cols-2">
            <div>
                <label className={LABEL}>Your interests</label>
                <input
                    type="text"
                    className={INPUT}
                    value={interests}
                    onChange={onInterestsChange}
                    placeholder="music, social apps, helping students..."
                    disabled={isDone or loading}
                />
            </div>
            <div>
                <label className={LABEL}>Your skills</label>
                <input
                    type="text"
                    className={INPUT}
                    value={skills}
                    onChange={onSkillsChange}
                    placeholder="Python, some web dev..."
                    disabled={isDone or loading}
                />
            </div>
        </div>

        {not isDone and <div className="mt-4 flex items-center gap-4">
            <PrimaryButton accent="gen" disabled={loading or not interests or not skills} onClick={onSubmit}>
                {"Brainstorming..." if loading else "Brainstorm Ideas →"}
            </PrimaryButton>
            {loading and <TypingDots />}
        </div>}

        {error and <div className="mt-4"><ErrorBanner message={error} /></div>}

        {ideas and <div className={RESULT}>
            <Markdown text={ideas} />
        </div>}
    </StepCard>;
}
