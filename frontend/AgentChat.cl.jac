"""Agent chat — streaming transcript beside a live view of the agent graph.

The diagram is NOT hand-drawn: `agent_architecture()` returns the real graph
from the server, and the SSE trace lights up whichever node is executing. What
you see is the running system, not a picture of it.
"""

import from "react-markdown" { default as ReactMarkdown }

glob STATUS_LABEL: dict = {
    "idle": "", "active": "running", "done": "done", "skipped": "skipped"
};

def:pub AgentChat() -> JsxElement {
    has arch: list[dict] = [];
    has turns: list[dict] = [];        # {role, text}
    has draft: str = "";         # assistant text streaming in right now
    has input_text: str = "";
    has busy: bool = False;
    has stage_state: dict = {};  # stage key  -> idle|active|done
    has cap_state: dict = {};    # cap key    -> idle|active|done|skipped
    has cap_detail: dict = {};   # cap key    -> short result summary
    has notes: list[dict] = [];        # {id,label,value} from Perceive/Plan
    has tools: list[dict] = [];        # {name,arg,phase,cap}
    has err: str = "";

    async can with entry {
        try {
            r: any = await fetch("/function/agent_architecture", {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": "{}"
            });
            payload: any = await r.json();
            arch = payload["data"]["result"]["stages"] as list[dict];
        } except Exception as e {
            err = "Could not load the agent graph: " + str(e);
        }
    }

    def reset_run() -> None {
        ss: dict = {};
        cs: dict = {};
        for st in arch {
            ss[st["key"]] = "idle";
            for c in (st["capabilities"] as list[dict]) { cs[c["key"]] = "idle"; }
        }
        stage_state = ss;
        cap_state = cs;
        cap_detail = {};
        notes = [];
        tools = [];
        err = "";
    }

    async def send() -> None {
        text = input_text.strip();
        if not text or busy { return; }
        input_text = "";

        # Everything below runs after `await`s, and reading a `has` field back
        # after an await yields the RENDER-TIME snapshot, not the latest write.
        # So the transcript is accumulated locally and assigned whole each time —
        # reading `turns` again at the end would silently drop this user turn.
        local_turns = turns + [{"role": "user", "text": text}];
        turns = local_turns;

        reset_run();
        busy = True;
        draft = "";

        acc = "";
        acc_notes = [];
        acc_tools = [];
        st_map = {};
        cp_map = {};
        cp_det = {};

        try {
            resp: any = await fetch("/function/agent_chat_stream", {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": JSON.stringify({"message": text})
            });
            reader: any = resp.body.getReader();
            # `new()` needs a resolvable class, so bind the JS constructor first.
            td_ctor: any = globalThis["TextDecoder"];
            decoder: any = new(td_ctor);
            nl = chr(10);
            buf = "";
            feeding = True;

            while feeding {
                part: any = await reader.read();
                if part.done { feeding = False; continue; }
                buf = buf + (decoder.decode(part.value, {"stream": True}) as str);
                frames = buf.split(nl + nl);
                buf = frames.pop();

                for frame in frames {
                    if frame.startswith("event:") { continue; }
                    for line in frame.split(nl) {
                        if not line.startswith("data: ") { continue; }
                        # Payloads are JSON-encoded on the wire, so each frame is
                        # a JSON *string* holding our JSON event. The server's
                        # closing `data: {}` frame is an object — skip it.
                        payload_txt = line[6:];
                        if not payload_txt.startswith(chr(34)) { continue; }
                        ev = JSON.parse(JSON.parse(payload_txt) as str);
                        kind = ev["t"];

                        if kind == "token" {
                            acc = acc + (ev["v"] as str);
                            draft = acc;
                        } elif kind == "stage" {
                            st_map[ev["id"]] = ev["status"];
                            stage_state = {**st_map};
                        } elif kind == "cap" {
                            cp_map[ev["id"]] = ev["status"];
                            cap_state = {**cp_map};
                            if ev["status"] == "done" {
                                cp_det[ev["id"]] = str(ev["detail"] or "");
                                cap_detail = {**cp_det};
                            }
                        } elif kind == "note" {
                            acc_notes = acc_notes + [ev];
                            notes = acc_notes;
                        } elif kind == "tool" {
                            acc_tools = acc_tools + [ev];
                            tools = acc_tools;
                        } elif kind == "error" {
                            err = str(ev["msg"]);
                        }
                    }
                }
            }
        } except Exception as e {
            err = str(e);
        } finally {
            # Always hand the composer back, even if the stream died mid-flight —
            # otherwise the textarea stays disabled and the turn is unrecoverable.
            if acc {
                local_turns = local_turns + [{"role": "assistant", "text": acc}];
                turns = local_turns;
            }
            draft = "";
            busy = False;
        }
    }

    async def clear_chat() -> None {
        if busy { return; }
        try {
            await fetch("/function/agent_reset", {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": "{}"
            });
        } except Exception as e { err = str(e); }
        turns = [];
        draft = "";
        reset_run();
    }

    def on_key(e: KeyboardEvent) -> None {
        if e.key == "Enter" and not e.shiftKey {
            e.preventDefault();
            send();
        }
    }

    return <div className="agent-wrap">

        {#* ── left: the agent graph, live ── *#}
        <aside className="agent-arch">
            <div className="arch-head">
                <div className="arch-title">Agent architecture</div>
                <div className="arch-sub">Read from the running graph — the lit node is where the agent is now.</div>
            </div>

            {for st in arch {
                <div key={st["key"]} className={"arch-stage " + (stage_state[st["key"]] or "idle")}>
                    <div className="arch-stage-row">
                        <span className="arch-ord">{str(st["ord"])}</span>
                        <span className="arch-label">{st["label"]}</span>
                        <span className="arch-status">{STATUS_LABEL[stage_state[st["key"]] or "idle"]}</span>
                    </div>
                    <div className="arch-blurb">{st["blurb"]}</div>

                    {if len(st["capabilities"] as list) > 0 {
                        <div className="arch-caps">
                            {for c in (st["capabilities"] as list[dict]) {
                                <div key={c["key"]} className={"arch-cap " + (cap_state[c["key"]] or "idle")}>
                                    <span className="cap-dot"></span>
                                    <span className="cap-label">{c["label"]}</span>
                                    <span className="cap-pattern">{c["pattern"]}</span>
                                    {if cap_detail[c["key"]] {
                                        <span className="cap-detail">{cap_detail[c["key"]]}</span>
                                    }}
                                </div>
                            }}
                        </div>
                    }}
                </div>
            }}

            {if len(notes) > 0 or len(tools) > 0 {
                <div className="trace">
                    <div className="trace-title">Trace</div>
                    {for n in notes {
                        <div key={str(n["id"]) + str(n["label"])} className="trace-row">
                            <span className="trace-k">{n["label"]}</span>
                            <span className="trace-v">{n["value"]}</span>
                        </div>
                    }}
                    {for (i, t) in enumerate(tools) {
                        <div key={"t" + str(i)} className={"trace-row tool " + t["phase"]}>
                            <span className="trace-k">{t["name"]}</span>
                            <span className="trace-v">
                                {t["arg"] if t["phase"] == "call" else ("← " + str(t["size"] or 0) + " chars")}
                            </span>
                        </div>
                    }}
                </div>
            }}
        </aside>

        {#* ── right: the conversation ── *#}
        <section className="agent-chat">
            <div className="chat-head">
                <div>
                    <div className="chat-title">Pitch Builder Agent</div>
                    <div className="chat-sub">Ask for ideas, a pitch, feasibility research, or mentor advice.</div>
                </div>
                <button className="btn-ghost" onClick={clear_chat} disabled={busy}>Clear</button>
            </div>

            <div className="chat-log">
                {if len(turns) == 0 and not draft {
                    <div className="chat-empty">
                        <p>Try one of these:</p>
                        <div className="chip-row">
                            {for s in [
                                "Give me 3 ideas about sustainability",
                                "Turn my study-partner app into a proper pitch",
                                "Is a real-time trivia game feasible in 24h?",
                                "What should I build first?"
                            ] {
                                <button key={s} className="chip"
                                        onClick={lambda { input_text = s; }}>{s}</button>
                            }}
                        </div>
                    </div>
                }}

                {for (i, t) in enumerate(turns) {
                    <div key={"m" + str(i)} className={"msg " + t["role"]}>
                        <div className="msg-role">{"You" if t["role"] == "user" else "Agent"}</div>
                        <div className="msg-body"><ReactMarkdown>{t["text"]}</ReactMarkdown></div>
                    </div>
                }}

                {if draft {
                    <div className="msg assistant">
                        <div className="msg-role">Agent</div>
                        <div className="msg-body">
                            <ReactMarkdown>{draft}</ReactMarkdown>
                            <span className="caret"></span>
                        </div>
                    </div>
                }}

                {if busy and not draft {
                    <div className="msg assistant">
                        <div className="msg-role">Agent</div>
                        <div className="msg-body thinking">
                            <span className="typing-dot"></span>
                            <span className="typing-dot"></span>
                            <span className="typing-dot"></span>
                        </div>
                    </div>
                }}

                {if err { <div className="error-banner">{err}</div> }}
            </div>

            <div className="chat-input">
                <textarea
                    value={input_text}
                    placeholder="Ask the agent anything about your hackathon project..."
                    rows={2}
                    disabled={busy}
                    onChange={lambda (e: ChangeEvent) { input_text = e.target.value; }}
                    onKeyDown={on_key}
                />
                <button className="btn btn-primary" onClick={send}
                        disabled={busy or not input_text.strip()}>
                    {"Working..." if busy else "Send"}
                </button>
            </div>
        </section>
    </div>;
}
