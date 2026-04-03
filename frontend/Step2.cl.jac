"""Step 2 — Extract
Takes the brainstormed ideas (editable), returns a typed HackathonPitch object.
The compiler enforces the schema — no parse-and-pray.
"""

def:pub Step2(props: dict) -> JsxElement {
    raw_idea  = props["rawIdea"] or "";
    pitch     = props["pitch"] or {};
    loading   = props["loading"] or False;
    error     = props["error"] or "";
    is_done   = props["isDone"] or False;
    is_locked = props["isLocked"] or False;

    status_label = "done" if is_done else ("active" if not is_locked else "locked");

    tech_stack = pitch["tech_stack"] or [];
    difficulty = pitch["difficulty"] or "";
    track      = pitch["track"] or "";

    return <div className={"step-card s2 " + ("done" if is_done else ("locked" if is_locked else "active"))}>
        <div className="step-header">
            <div className="step-num">2</div>
            <div className="step-meta">
                <div className="step-title">Extract — Structure Pitch</div>
                <div className="step-subtitle">LLM returns a typed object — compiler enforces the schema</div>
            </div>
            <span className={"step-status " + status_label}>
                {"✓ done" if is_done else ("running" if loading else ("locked" if is_locked else "ready"))}
            </span>
        </div>

        <div className="step-body">
            {not is_done and <div>
                <div className="input-group" style={{"marginBottom": "14px"}}>
                    <label>Your idea (edit or paste a new one)</label>
                    <textarea
                        value={raw_idea}
                        onChange={props["onRawIdeaChange"]}
                        placeholder="Describe your hackathon idea..."
                        rows={4}
                        disabled={loading}
                    />
                </div>

                <button
                    className="btn btn-primary s2"
                    onClick={props["onSubmit"]}
                    disabled={loading or not raw_idea}
                >
                    {loading and "Structuring..." or "Structure Pitch →"}
                </button>
            </div>}

            {loading and <div className="typing-indicator">
                <div className="typing-dot"></div>
                <div className="typing-dot"></div>
                <div className="typing-dot"></div>
            </div>}

            {error and <div className="error-banner">{error}</div>}

            {pitch["title"] and <div className="result-area">
                <hr />
                <div className="pitch-grid">
                    <div className="pitch-field full">
                        <div className="pitch-field-label">Project Title</div>
                        <div className="pitch-field-value title">{pitch["title"]}</div>
                        <div className="badge-row" style={{"marginTop": "8px"}}>
                            <span className={"meta-badge difficulty-" + difficulty}>{difficulty}</span>
                            <span className="meta-badge">{track}</span>
                        </div>
                    </div>
                    <div className="pitch-field">
                        <div className="pitch-field-label">Problem</div>
                        <div className="pitch-field-value">{pitch["problem"] or ""}</div>
                    </div>
                    <div className="pitch-field">
                        <div className="pitch-field-label">Solution</div>
                        <div className="pitch-field-value">{pitch["solution"] or ""}</div>
                    </div>
                    <div className="pitch-field full">
                        <div className="pitch-field-label">Wow Factor ✨</div>
                        <div className="pitch-field-value">{pitch["wow_factor"] or ""}</div>
                    </div>
                    <div className="pitch-field full">
                        <div className="pitch-field-label">Tech Stack</div>
                        <div className="tag-list">
                            {[<span key={t} className="tag">{t}</span> for t in tech_stack]}
                        </div>
                    </div>
                </div>
                <button className="btn btn-copy-idea" onClick={props["onCopyToStep3"]}>
                    Use this pitch for research →
                </button>
            </div>}
        </div>
    </div>;
}
