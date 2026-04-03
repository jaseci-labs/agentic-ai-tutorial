"""Step 3 — Invoke
Give the LLM tools (GitHub search, tech stack, time estimate).
It runs the ReAct loop: reason → call tool → observe → repeat.
"""

import from "react-markdown" { default as ReactMarkdown }

def:pub Step3(props: dict) -> JsxElement {
    idea     = props["idea"] or "";
    research = props["research"] or "";
    loading  = props["loading"] or False;
    error    = props["error"] or "";
    is_done  = props["isDone"] or False;
    is_locked = props["isLocked"] or False;

    status_label = "done" if is_done else ("active" if not is_locked else "locked");

    return <div className={"step-card s3 " + ("done" if is_done else ("locked" if is_locked else "active"))}>
        <div className="step-header">
            <div className="step-num">3</div>
            <div className="step-meta">
                <div className="step-title">Invoke — Research</div>
                <div className="step-subtitle">LLM calls tools autonomously: GitHub search, tech stack, feasibility</div>
            </div>
            <span className={"step-status " + status_label}>
                {"✓ done" if is_done else ("running" if loading else ("locked" if is_locked else "ready"))}
            </span>
        </div>

        <div className="step-body">
            {not is_done and <div>
                <div className="input-group" style={{"marginBottom": "14px"}}>
                    <label>Idea to research (pre-filled from your pitch)</label>
                    <textarea
                        value={idea}
                        onChange={props["onIdeaChange"]}
                        placeholder="Describe your idea for the agent to research..."
                        rows={3}
                        disabled={loading}
                    />
                </div>

                <button
                    className="btn btn-primary s3"
                    onClick={props["onSubmit"]}
                    disabled={loading or not idea}
                >
                    {loading and "Researching..." or "Research Idea →"}
                </button>
            </div>}

            {loading and <div>
                <div className="typing-indicator">
                    <div className="typing-dot"></div>
                    <div className="typing-dot"></div>
                    <div className="typing-dot"></div>
                </div>
                <div style={{"fontSize": "12px", "color": "var(--text-dim)", "marginTop": "4px"}}>
                    Searching GitHub, analyzing tech stack, estimating build time...
                </div>
            </div>}

            {error and <div className="error-banner">{error}</div>}

            {research and <div className="result-area">
                <hr />
                <div className="result-text"><ReactMarkdown>{research}</ReactMarkdown></div>
            </div>}
        </div>
    </div>;
}
