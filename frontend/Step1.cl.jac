"""Step 1 — Generate
Brainstorm form: interests + skills → free-text ideas.
Pure presentational component; App.cl.jac owns state and calls the server.
"""

import from "react-markdown" { default as ReactMarkdown }

def:pub Step1(props: dict) -> JsxElement {
    interests = props["interests"] or "";
    skills    = props["skills"] or "";
    ideas     = props["ideas"] or "";
    loading   = props["loading"] or False;
    error     = props["error"] or "";
    is_done   = props["isDone"] or False;
    is_locked = props["isLocked"] or False;

    status_label = "done" if is_done else ("active" if not is_locked else "locked");

    return <div className={"step-card s1 " + ("done" if is_done else ("locked" if is_locked else "active"))}>
        <div className="step-header">
            <div className="step-num">1</div>
            <div className="step-meta">
                <div className="step-title">Generate — Brainstorm</div>
                <div className="step-subtitle">LLM returns free text from a function signature</div>
            </div>
            <span className={"step-status " + status_label}>
                {"✓ done" if is_done else ("running" if loading else ("locked" if is_locked else "ready"))}
            </span>
        </div>

        <div className="step-body">
            <div className="input-row">
                <div className="input-group">
                    <label>Your interests</label>
                    <input
                        type="text"
                        value={interests}
                        onChange={props["onInterestsChange"]}
                        placeholder="music, social apps, helping students..."
                        disabled={is_done or loading}
                    />
                </div>
                <div className="input-group">
                    <label>Your skills</label>
                    <input
                        type="text"
                        value={skills}
                        onChange={props["onSkillsChange"]}
                        placeholder="Python, some web dev..."
                        disabled={is_done or loading}
                    />
                </div>
            </div>

            {not is_done and <button
                className="btn btn-primary"
                onClick={props["onSubmit"]}
                disabled={loading or not interests or not skills}
            >
                {loading and "Brainstorming..."  or "Brainstorm Ideas →"}
            </button>}

            {loading and <div className="typing-indicator">
                <div className="typing-dot"></div>
                <div className="typing-dot"></div>
                <div className="typing-dot"></div>
            </div>}

            {error and <div className="error-banner">{error}</div>}

            {ideas and <div className="result-area">
                <hr />
                <div className="result-text"><ReactMarkdown>{ideas}</ReactMarkdown></div>
            </div>}
        </div>
    </div>;
}
