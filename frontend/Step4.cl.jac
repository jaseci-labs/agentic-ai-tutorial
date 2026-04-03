"""Step 4 — Route
LLM reads node descriptions, picks the most relevant expert mentor(s), then
streams each mentor's advice token-by-token. No if/else — the graph IS the
routing table. Add a new node to add a new route.
"""

import from "react-markdown" { default as ReactMarkdown }

def:pub Step4(props: dict) -> JsxElement {
    pitch          = props["pitch"] or "";
    mentor_results = props["mentorResults"] or [];
    loading        = props["loading"] or False;
    error          = props["error"] or "";
    is_done        = props["isDone"] or False;
    is_locked      = props["isLocked"] or False;

    has active_tab: int = 0;

    status_label = "done" if is_done else ("active" if not is_locked else "locked");

    def mentor_color(name: str) -> str {
        if "Web" in name { return "var(--accent-s1)"; }
        if "Mobile" in name { return "var(--accent-s2)"; }
        if "AI" in name or "ML" in name { return "var(--accent-s3)"; }
        if "Game" in name { return "var(--accent-s4)"; }
        return "#a78bfa";
    }

    all_mentors = ["Web Dev", "Mobile", "AI/ML", "Game Dev", "Jac Expert"];
    n = len(mentor_results);
    cur = mentor_results[active_tab] if n > 0 and active_tab < n else {};
    cur_mentor  = cur["mentor"] or "" if cur else "";
    cur_advice  = cur["advice"] or "" if cur else "";
    cur_loading = cur["loading"] or False if cur else False;

    return <div className={"step-card s4 " + ("done" if is_done else ("locked" if is_locked else "active"))}>
        <div className="step-header">
            <div className="step-num">4</div>
            <div className="step-meta">
                <div className="step-title">Route — Get Mentor Advice</div>
                <div className="step-subtitle">LLM reads node descriptions and picks the right expert(s)</div>
            </div>
            <span className={"step-status " + status_label}>
                {"✓ done" if is_done else ("routing..." if loading else ("locked" if is_locked else "ready"))}
            </span>
        </div>

        <div className="step-body">
            {not is_done and <div>
                <div style={{"marginBottom": "14px"}}>
                    <div style={{"fontSize": "11px", "color": "var(--text-dim)", "marginBottom": "6px"}}>
                        Available mentors (LLM picks the best match):
                    </div>
                    <div style={{"display": "flex", "gap": "6px", "flexWrap": "wrap"}}>
                        {[
                            <span key={m} style={{
                                "fontSize": "11px",
                                "padding": "4px 10px",
                                "borderRadius": "20px",
                                "background": "var(--surface-2)",
                                "border": "1px solid var(--border)",
                                "color": "var(--text-dim)"
                            }}>{m}</span>
                            for m in all_mentors
                        ]}
                    </div>
                </div>

                <button
                    className="btn btn-primary s4"
                    onClick={props["onSubmit"]}
                    disabled={loading or not pitch}
                >
                    {"Get Mentor Advice →"}
                </button>

                {loading and <div style={{"marginTop": "16px"}}>
                    <div className="typing-indicator">
                        <div className="typing-dot"></div>
                        <div className="typing-dot"></div>
                        <div className="typing-dot"></div>
                    </div>
                    <div style={{"fontSize": "12px", "color": "var(--text-dim)", "marginTop": "4px"}}>
                        Walker routing to best mentor(s), spawning parallel advice workers...
                    </div>
                </div>}
            </div>}

            {error and <div className="error-banner">{error}</div>}

            {n > 0 and <div className="result-area">
                <hr />

                # Tab bar — mentor names visible as soon as routing completes
                <div style={{
                    "display": "flex",
                    "gap": "4px",
                    "marginBottom": "16px",
                    "flexWrap": "wrap",
                    "borderBottom": "1px solid var(--border)"
                }}>
                    {[
                        <button
                            key={i}
                            onClick={lambda -> None { active_tab = i; }}
                            style={{
                                "padding": "8px 14px",
                                "fontSize": "12px",
                                "fontWeight": "600",
                                "border": "none",
                                "borderBottom": ("2px solid " + mentor_color(mentor_results[i]["mentor"] or "")) if active_tab == i else "2px solid transparent",
                                "background": "transparent",
                                "color": mentor_color(mentor_results[i]["mentor"] or "") if active_tab == i else "var(--text-dim)",
                                "cursor": "pointer",
                                "transition": "all 0.15s",
                                "whiteSpace": "nowrap",
                                "display": "flex",
                                "alignItems": "center",
                                "gap": "6px"
                            }}
                        >
                            {mentor_results[i]["mentor"] or ""}
                            {mentor_results[i]["loading"] and <span style={{"display": "inline-flex", "gap": "2px", "alignItems": "center"}}>
                                <span style={{"width": "4px", "height": "4px", "borderRadius": "50%", "background": "currentColor", "opacity": "0.6", "animation": "pulse 1s infinite"}}></span>
                                <span style={{"width": "4px", "height": "4px", "borderRadius": "50%", "background": "currentColor", "opacity": "0.6", "animation": "pulse 1s 0.2s infinite"}}></span>
                                <span style={{"width": "4px", "height": "4px", "borderRadius": "50%", "background": "currentColor", "opacity": "0.6", "animation": "pulse 1s 0.4s infinite"}}></span>
                            </span>}
                        </button>
                        for i in range(n)
                    ]}
                </div>

                # Active tab content
                {cur and <div className="mentor-card">
                    <div className="mentor-name" style={{"color": mentor_color(cur_mentor)}}>
                        {cur_mentor} Mentor
                    </div>

                    {cur_loading and cur_advice == "" and <div style={{"padding": "12px 0"}}>
                        <div className="typing-indicator">
                            <div className="typing-dot"></div>
                            <div className="typing-dot"></div>
                            <div className="typing-dot"></div>
                        </div>
                        <div style={{"fontSize": "12px", "color": "var(--text-dim)", "marginTop": "4px"}}>
                            {cur_mentor} is preparing advice...
                        </div>
                    </div>}

                    {cur_advice and <div className="mentor-advice">
                        <ReactMarkdown>{cur_advice}</ReactMarkdown>
                        {cur_loading and <span style={{
                            "display": "inline-block",
                            "width": "2px",
                            "height": "1em",
                            "background": mentor_color(cur_mentor),
                            "marginLeft": "2px",
                            "verticalAlign": "text-bottom",
                            "animation": "pulse 0.8s infinite"
                        }}></span>}
                    </div>}
                </div>}
            </div>}
        </div>
    </div>;
}
