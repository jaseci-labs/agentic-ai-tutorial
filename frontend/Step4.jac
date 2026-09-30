"""Step 4 — Route
LLM reads node descriptions, picks the most relevant expert mentor(s), then
streams each mentor's advice token-by-token. No if/else — the graph IS the
routing table. Add a new node to add a new route.
"""

import from ui { StepCard, PrimaryButton, TypingDots, ErrorBanner, Markdown, RESULT }

# Text + underline colour of a mentor's tab once it is selected.
glob MENTOR_TAB: dict[str, str] = {
    "Web Dev": "border-gen text-gen",
    "Mobile": "border-ext text-ext",
    "AI/ML": "border-inv text-inv",
    "Game Dev": "border-rte text-rte",
    "Jac Expert": "border-fuchsia-300 text-fuchsia-300"
};

glob MENTOR_NAME: dict[str, str] = {
    "Web Dev": "text-gen",
    "Mobile": "text-ext",
    "AI/ML": "text-inv",
    "Game Dev": "text-rte",
    "Jac Expert": "text-fuchsia-300"
};

def:pub Step4(
    pitch: str,
    mentorResults: list[any],
    loading: bool,
    error: str,
    isDone: bool,
    isLocked: bool,
    onSubmit: Callable[[], None]
) -> JsxElement {
    has active_tab: int = 0;

    state = "done" if isDone else ("locked" if isLocked else "active");

    all_mentors = ["Web Dev", "Mobile", "AI/ML", "Game Dev", "Jac Expert"];
    n = len(mentorResults);
    cur = mentorResults[active_tab] if n > 0 and active_tab < n else {};
    cur_mentor  = str(cur["mentor"] or "") if cur else "";
    cur_advice  = str(cur["advice"] or "") if cur else "";
    cur_loading = cur["loading"] or False if cur else False;

    return <StepCard
        num={4}
        accent="rte"
        title="Route — Get Mentor Advice"
        subtitle="LLM reads node descriptions and picks the right expert(s)"
        state={state}
        busy={loading}
        busyLabel="routing..."
        last={True}
    >
        {not isDone and <div>
            <div className="text-xs text-dim">Available mentors (LLM picks the best match):</div>
            <div className="mt-2 flex flex-wrap gap-1.5">
                {[
                    <span key={m} className="rounded-full border border-line bg-panel-2 px-2.5 py-1 text-xs text-dim">{m}</span>
                    for m in all_mentors
                ]}
            </div>

            <div className="mt-4 flex flex-wrap items-center gap-4">
                <PrimaryButton accent="rte" disabled={loading or not pitch} onClick={onSubmit}>
                    Get Mentor Advice →
                </PrimaryButton>
                {loading and <TypingDots label="Walker routing to best mentor(s), spawning parallel advice workers..." />}
            </div>
        </div>}

        {error and <div className="mt-4"><ErrorBanner message={error} /></div>}

        {n > 0 and <div className={"" if isDone else RESULT}>
            {#* Tab bar — one tab per mentor the LLM routed to *#}
            <div className="flex flex-wrap gap-1 border-b border-line">
                {[
                    <button
                        key={i}
                        onClick={lambda { active_tab = i; }}
                        className={"-mb-px flex items-center gap-1.5 border-b-2 px-3 py-2 text-xs font-semibold whitespace-nowrap transition "
                            + ((MENTOR_TAB[str(mentorResults[i]["mentor"] or "")] or "border-fg text-fg") if active_tab == i else "border-transparent text-dim hover:text-fg")}
                    >
                        {mentorResults[i]["mentor"] or ""}
                        {mentorResults[i]["loading"] and <span className="size-1 animate-pulse rounded-full bg-current"></span>}
                    </button>
                    for i in range(n)
                ]}
            </div>

            {cur and <div className="pt-4">
                <div className={"mb-3 text-[11px] font-semibold tracking-wider uppercase " + (MENTOR_NAME[cur_mentor] or "text-fg")}>
                    {cur_mentor} Mentor
                </div>

                {cur_loading and cur_advice == "" and <TypingDots label={cur_mentor + " is preparing advice..."} />}

                {cur_advice and <Markdown text={cur_advice} />}
            </div>}
        </div>}
    </StepCard>;
}
