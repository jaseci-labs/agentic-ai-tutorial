"""Agent chat — streaming transcript beside a live view of the agent graph.

The diagram is NOT hand-drawn: `agent_architecture()` returns the real graph
from the server, and the SSE trace lights up whichever node is executing. What
you see is the running system, not a picture of it.
"""

import from ui { Markdown, TypingDots, ErrorBanner }

glob STATUS_LABEL: dict[str, str] = {
    "idle": "", "active": "running", "done": "done", "skipped": "skipped"
};

# Tailwind classes per execution state. Whole strings, so Tailwind can see them —
# a name assembled at run time ("border-" + state) would produce no CSS.
glob STAGE_BOX: dict[str, str] = {
    "idle": "border-line bg-panel-2/40",
    "active": "border-brand/60 bg-brand/10 shadow-lg shadow-brand/10",
    "done": "border-ok/25 bg-ok/5"
};

glob STAGE_NUM: dict[str, str] = {
    "idle": "bg-panel-2 text-dim",
    "active": "animate-pulse bg-brand text-white",
    "done": "bg-ok/15 text-ok"
};

glob STAGE_STATUS: dict[str, str] = {
    "idle": "text-faint",
    "active": "text-gen",
    "done": "text-ok"
};

glob CAP_ROW: dict[str, str] = {
    "idle": "border-transparent text-dim",
    "active": "border-brand/40 bg-brand/10 text-fg",
    "done": "border-line bg-panel-2 text-fg",
    "skipped": "border-transparent text-faint opacity-50"
};

glob CAP_DOT: dict[str, str] = {
    "idle": "bg-faint",
    "active": "animate-pulse bg-brand",
    "done": "bg-ok",
    "skipped": "bg-faint"
};

glob PANEL: str = "rounded-2xl border border-line bg-panel shadow-lg shadow-black/20";

glob GHOST_BTN: str = "rounded-lg border border-line px-3 py-1.5 text-xs font-medium text-dim transition hover:border-line-strong hover:text-fg disabled:cursor-not-allowed disabled:opacity-40";

def:pub AgentChat() -> JsxElement {
    has arch: list[dict[str, any]] = [];
    has turns: list[dict[str, any]] = [];  # {role, text}
    has draft: str = "";         # assistant text streaming in right now
    has input_text: str = "";
    has busy: bool = False;
    has stage_state: dict[str, str] = {};  # stage key  -> idle|active|done
    has cap_state: dict[str, str] = {};    # cap key    -> idle|active|done|skipped
    has cap_detail: dict[str, str] = {};   # cap key    -> short result summary
    has notes: list[dict[str, any]] = [];  # {id,label,value} from Perceive/Plan
    has tools: list[dict[str, any]] = [];  # {name,arg,phase,cap}
    has err: str = "";
    has sessions: list[dict[str, any]] = [];
    has sid: str = "";           # active session

    async can with entry {
        try {
            r: any = await fetch("/function/agent_architecture", {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": "{}"
            });
            payload: any = await r.json();
            arch = payload["data"]["result"]["stages"] as list[dict[str, any]];
        } except Exception as e {
            err = "Could not load the agent graph: " + str(e);
        }
        await load_sessions();
    }

    async def load_sessions() -> None {
        try {
            r: any = await fetch("/function/agent_sessions", {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": "{}"
            });
            j: any = await r.json();
            sessions = j["data"]["result"]["sessions"] as list[dict[str, any]];
        } except Exception as e { err = str(e); }
    }

    async def open_session(target: str) -> None {
        if busy { return; }
        sid = target;
        draft = "";
        reset_run();
        try {
            r: any = await fetch("/function/agent_history", {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": JSON.stringify({"sid": target})
            });
            j: any = await r.json();
            turns = j["data"]["result"]["turns"] as list[dict[str, any]];
        } except Exception as e { err = str(e); }
    }

    async def new_session() -> None {
        if busy { return; }
        try {
            r: any = await fetch("/function/agent_new_session", {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": "{}"
            });
            j: any = await r.json();
            created: any = j["data"]["result"]["session"];
            sid = str(created["sid"]);
            turns = [];
            draft = "";
            reset_run();
            await load_sessions();
        } except Exception as e { err = str(e); }
    }

    async def delete_session(target: str) -> None {
        if busy { return; }
        try {
            await fetch("/function/agent_delete_session", {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": JSON.stringify({"sid": target})
            });
            if target == sid { sid = ""; turns = []; draft = ""; }
            await load_sessions();
        } except Exception as e { err = str(e); }
    }

    def reset_run() -> None {
        ss: dict[str, str] = {};
        cs: dict[str, str] = {};
        for st in arch {
            ss[st["key"]] = "idle";
            for c in (st["capabilities"] as list[dict[str, any]]) { cs[c["key"]] = "idle"; }
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
                "body": JSON.stringify({"message": text, "session_id": sid})
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
                        } elif kind == "session" {
                            # the server tells us which session this landed in
                            # (and the auto-generated title on the first turn)
                            sid = str(ev["sid"]);
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
        await load_sessions();   # pick up turn counts and the auto-title
    }

    def on_key(e: KeyboardEvent) -> None {
        if e.key == "Enter" and not e.shiftKey {
            e.preventDefault();
            send();
        }
    }

    return <div className="grid items-start gap-4 lg:grid-cols-[19rem_minmax(0,1fr)] xl:grid-cols-[19rem_minmax(0,1fr)_15rem]">

        {#* ── left: the agent graph, live ── *#}
        <aside className={PANEL + " order-2 p-4 lg:order-1"}>
            <div className="text-sm font-semibold tracking-tight text-fg">Agent architecture</div>
            <p className="mt-1 text-xs leading-relaxed text-dim">
                Read from the running graph — the lit node is where the agent is now.
            </p>

            <div className="mt-4 space-y-2">
                {for st in arch {
                    <div key={st["key"]} className={"rounded-xl border p-3 transition-colors " + STAGE_BOX[stage_state[st["key"]] or "idle"]}>
                        <div className="flex items-center gap-2.5">
                            <span className={"grid size-6 shrink-0 place-items-center rounded-md text-xs font-semibold " + STAGE_NUM[stage_state[st["key"]] or "idle"]}>
                                {str(st["ord"])}
                            </span>
                            <span className="text-sm font-semibold text-fg">{st["label"]}</span>
                            <span className={"ml-auto text-[11px] font-medium " + STAGE_STATUS[stage_state[st["key"]] or "idle"]}>
                                {STATUS_LABEL[stage_state[st["key"]] or "idle"]}
                            </span>
                        </div>
                        <p className="mt-2 text-xs leading-relaxed text-dim">{st["blurb"]}</p>

                        {if len(st["capabilities"] as list[any]) > 0 {
                            <div className="mt-3 space-y-1">
                                {for c in (st["capabilities"] as list[dict[str, any]]) {
                                    <div key={c["key"]} className={"flex flex-wrap items-center gap-x-2 gap-y-0.5 rounded-lg border px-2.5 py-1.5 text-xs transition-colors " + CAP_ROW[cap_state[c["key"]] or "idle"]}>
                                        <span className={"size-1.5 shrink-0 rounded-full " + CAP_DOT[cap_state[c["key"]] or "idle"]}></span>
                                        <span className="font-medium">{c["label"]}</span>
                                        <span className="ml-auto text-[10px] text-faint">{c["pattern"]}</span>
                                        {if cap_detail[c["key"]] {
                                            <span className="basis-full truncate pl-3.5 text-[11px] text-dim">{cap_detail[c["key"]]}</span>
                                        }}
                                    </div>
                                }}
                            </div>
                        }}
                    </div>
                }}
            </div>

            {if len(notes) > 0 or len(tools) > 0 {
                <div className="mt-4 border-t border-line pt-4">
                    <div className="text-[11px] font-semibold tracking-wider text-faint uppercase">Trace</div>
                    <div className="mt-2 space-y-1.5 font-mono text-[11px] leading-relaxed">
                        {for n in notes {
                            <div key={str(n["id"]) + str(n["label"])} className="grid grid-cols-[4.5rem_minmax(0,1fr)] gap-2">
                                <span className="text-faint">{n["label"]}</span>
                                <span className="break-words text-fg/90">{n["value"]}</span>
                            </div>
                        }}
                        {for (i, t) in enumerate(tools) {
                            <div key={"t" + str(i)} className="grid grid-cols-[4.5rem_minmax(0,1fr)] gap-2">
                                <span className={"truncate " + ("text-inv" if t["phase"] == "call" else "text-faint")}>{t["name"]}</span>
                                <span className={"break-words " + ("text-fg/90" if t["phase"] == "call" else "text-faint")}>
                                    {t["arg"] if t["phase"] == "call" else ("← " + str(t["size"] or 0) + " chars")}
                                </span>
                            </div>
                        }}
                    </div>
                </div>
            }}
        </aside>

        {#* ── centre: the conversation ── *#}
        <section className={PANEL + " order-1 flex h-[calc(100vh-24rem)] min-h-[28rem] flex-col lg:sticky lg:top-6 lg:order-2"}>
            <div className="flex items-center gap-3 border-b border-line px-5 py-4">
                <div className="min-w-0 flex-1">
                    <div className="text-[15px] font-semibold tracking-tight text-fg">Pitch Builder Agent</div>
                    <div className="mt-0.5 text-sm text-dim">Ask for ideas, a pitch, feasibility research, or mentor advice.</div>
                </div>
                <button className={GHOST_BTN + " shrink-0"} onClick={new_session} disabled={busy}>New chat</button>
            </div>

            {#* flex-col-reverse pins the scroll position to the newest message *#}
            <div className="flex flex-1 flex-col-reverse overflow-y-auto">
                <div className="space-y-5 p-5">
                    {if len(turns) == 0 and not draft and not busy {
                        <div className="py-6 text-center">
                            <p className="text-sm text-dim">Try one of these:</p>
                            <div className="mt-3 flex flex-wrap justify-center gap-2">
                                {for s in [
                                    "Give me 3 ideas about sustainability",
                                    "Turn my study-partner app into a proper pitch",
                                    "Is a real-time trivia game feasible in 24h?",
                                    "What should I build first?"
                                ] {
                                    <button
                                        key={s}
                                        className="rounded-full border border-line bg-panel-2 px-3 py-1.5 text-xs text-dim transition hover:border-brand/50 hover:text-fg"
                                        onClick={lambda { input_text = s; }}
                                    >
                                        {s}
                                    </button>
                                }}
                            </div>
                        </div>
                    }}

                    {for (i, t) in enumerate(turns) {
                        <div key={"m" + str(i)} className={"flex " + ("justify-end" if t["role"] == "user" else "justify-start")}>
                            {if t["role"] == "user" {
                                <div className="max-w-[85%] rounded-2xl rounded-br-md bg-brand px-4 py-2.5 text-sm leading-relaxed break-words whitespace-pre-wrap text-white">
                                    {t["text"]}
                                </div>
                            }}
                            {if t["role"] != "user" {
                                <div className="max-w-[92%] min-w-0 rounded-2xl rounded-bl-md border border-line bg-panel-2 px-4 py-3">
                                    <Markdown text={str(t["text"])} />
                                </div>
                            }}
                        </div>
                    }}

                    {if draft {
                        <div className="flex justify-start">
                            <div className="max-w-[92%] min-w-0 rounded-2xl rounded-bl-md border border-brand/30 bg-panel-2 px-4 py-3">
                                <Markdown text={draft} />
                                <span className="mt-1 inline-block h-4 w-0.5 animate-pulse bg-gen align-text-bottom"></span>
                            </div>
                        </div>
                    }}

                    {if busy and not draft {
                        <div className="flex justify-start">
                            <div className="rounded-2xl rounded-bl-md border border-line bg-panel-2 px-4 py-3.5">
                                <TypingDots />
                            </div>
                        </div>
                    }}

                    {if err { <ErrorBanner message={err} /> }}
                </div>
            </div>

            <div className="border-t border-line p-3">
                <div className="flex items-end gap-2 rounded-xl border border-line bg-canvas/60 p-2 transition focus-within:border-line-strong focus-within:ring-2 focus-within:ring-brand/30">
                    <textarea
                        className="max-h-40 min-h-10 flex-1 resize-none bg-transparent px-2 py-1.5 text-sm text-fg placeholder:text-faint focus:outline-none disabled:opacity-60"
                        value={input_text}
                        placeholder="Ask the agent anything about your hackathon project..."
                        rows={2}
                        disabled={busy}
                        onChange={lambda (e: ChangeEvent) { input_text = e.target.value; }}
                        onKeyDown={on_key}
                    />
                    <button
                        className="shrink-0 rounded-lg bg-brand px-4 py-2 text-sm font-semibold text-white transition hover:bg-brand/85 disabled:cursor-not-allowed disabled:opacity-40"
                        onClick={send}
                        disabled={busy or not input_text.strip()}
                    >
                        {"Working..." if busy else "Send"}
                    </button>
                </div>
            </div>
        </section>

        {#* ── right: session menu ── *#}
        <aside className={PANEL + " order-3 p-4 lg:col-span-2 xl:sticky xl:top-6 xl:col-span-1"}>
            <div className="flex items-center justify-between">
                <span className="text-[11px] font-semibold tracking-wider text-faint uppercase">Chats</span>
                <button className={GHOST_BTN} onClick={new_session} disabled={busy}>+ New</button>
            </div>

            {if len(sessions) == 0 {
                <p className="mt-4 text-xs leading-relaxed text-dim">No chats yet — send a message to start one.</p>
            }}

            <div className="mt-3 space-y-1.5">
                {for s in sessions {
                    <div key={s["sid"]} className={"group flex items-center gap-1 rounded-lg border transition-colors " + ("border-brand/50 bg-brand/10" if s["sid"] == sid else "border-transparent hover:bg-panel-2")}>
                        <button className="min-w-0 flex-1 px-3 py-2 text-left" onClick={lambda { open_session(str(s["sid"])); }}>
                            <span className={"block truncate text-sm " + ("font-medium text-fg" if s["sid"] == sid else "text-fg/90")}>{s["title"]}</span>
                            <span className="mt-0.5 block text-[11px] text-faint">
                                {str(s["turns"]) + " msg"}{" · "}{str(s["created"])[5:10]}
                            </span>
                        </button>
                        <button
                            className="mr-1.5 grid size-6 shrink-0 place-items-center rounded-md text-base leading-none text-faint opacity-0 transition group-hover:opacity-100 hover:bg-bad/10 hover:text-bad focus-visible:opacity-100"
                            title="Delete chat"
                            onClick={lambda { delete_session(str(s["sid"])); }}
                        >
                            ×
                        </button>
                    </div>
                }}
            </div>

            <p className="mt-4 border-t border-line pt-3 text-[11px] leading-relaxed text-faint">
                Sessions are nodes on <code className="rounded bg-panel-2 px-1 py-0.5 font-mono text-dim">root</code> — they persist across restarts,
                with no database and no auth.
            </p>
        </aside>
    </div>;
}
