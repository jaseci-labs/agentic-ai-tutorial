"""Step 3 — Invoke
Give the LLM tools (GitHub search, tech stack, time estimate).
It runs the ReAct loop: reason → call tool → observe → repeat.
"""

import from ui { StepCard, PrimaryButton, TypingDots, ErrorBanner, Markdown, LABEL, INPUT, RESULT }

def:pub Step3(
    idea: str,
    research: str,
    loading: bool,
    error: str,
    isDone: bool,
    isLocked: bool,
    onIdeaChange: Callable[[ChangeEvent], None],
    onSubmit: Callable[[], None]
) -> JsxElement {
    state = "done" if isDone else ("locked" if isLocked else "active");

    return <StepCard
        num={3}
        accent="inv"
        title="Invoke — Research"
        subtitle="LLM calls tools autonomously: GitHub search, tech stack, feasibility"
        state={state}
        busy={loading}
    >
        {not isDone and <div>
            <label className={LABEL}>Idea to research (pre-filled from your pitch)</label>
            <textarea
                className={INPUT + " resize-y"}
                value={idea}
                onChange={onIdeaChange}
                placeholder="Describe your idea for the agent to research..."
                rows={3}
                disabled={loading}
            />
            <div className="mt-4 flex flex-wrap items-center gap-4">
                <PrimaryButton accent="inv" disabled={loading or not idea} onClick={onSubmit}>
                    {"Researching..." if loading else "Research Idea →"}
                </PrimaryButton>
                {loading and <TypingDots label="Searching GitHub, analyzing tech stack, estimating build time..." />}
            </div>
        </div>}

        {error and <div className="mt-4"><ErrorBanner message={error} /></div>}

        {research and <div className={"" if isDone else RESULT}>
            <Markdown text={research} />
        </div>}
    </StepCard>;
}
