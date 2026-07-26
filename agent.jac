"""The agent — a conversational front end that composes all four patterns.

ARCHITECTURE
════════════
The agent is not a tool-loop. It is a **graph you can look at**, and the
walker's position in that graph is the agent's state:

    Perceive ──> Plan ──> Act ──> Synthesize
                           │
                           ├── Brainstorm   (Generate)
                           ├── Structure    (Extract)
                           ├── Research     (Invoke — tools/ReAct)
                           └── Mentors      (Route + Spawn — parallel)

Six properties make this worth copying:

  1. THE GRAPH IS THE ARCHITECTURE. Topology is data, built once under `root`.
     `agent_architecture()` reads that same graph back, so the diagram in the
     UI is derived from the running system and cannot drift from it.

  2. BEHAVIOUR LIVES ON NODES. Each capability implements its own
     `can ... with CapabilityExec entry` ability. There is no central dispatch
     `if/elif` chain — adding a capability means adding a node, not editing a
     switch.

  3. TYPED CONTRACTS BETWEEN STAGES. Perceive yields an `Intent`, Plan yields
     a `Plan`. These are `obj`s the compiler enforces, not free text that the
     next stage has to re-parse and hope about.

  4. THE PLAN DIRECTS THE ROUTE. Which capabilities run is decided by a typed
     plan, not hardcoded. Small talk runs zero capabilities and costs two LLM
     calls; a full pitch request runs four capabilities.

  5. COGNITION IS SEPARATE FROM TRANSPORT. Stages know nothing about HTTP.
     `agent_chat_stream` is a thin adapter that walks the graph and turns
     stage boundaries into SSE frames — swap it for a CLI and nothing changes.

  6. THE AGENT NARRATES ITSELF. Stages, capabilities and individual tool calls
     all publish to one event bus, so the trace the UI draws IS the execution
     path rather than a reconstruction of it. Capabilities run on a worker
     thread while the endpoint drains that bus, which is what makes a tool call
     visible the moment it happens instead of after the step finishes.

Concurrency note: the bus and run slot below are module-level, so one server
handles one conversation at a time. That keeps the example readable; a
multi-tenant version would key both by session id.
"""

import json;
import from queue { Queue }
import from typing { Generator }
import from tools { search_github, describe_tech_stack, estimate_build_time }

# ── The event bus ─────────────────────────────────────────────────────────────

glob BUS: Queue = Queue();
glob SLOT: dict = {};

def emit(ev: dict) -> None {
    BUS.put(ev);
}

# ── Instrumented tools — the ReAct loop narrates itself ───────────────────────
# The LLM is handed these wrappers rather than the raw tools, so every call it
# decides to make becomes a frame on the wire the instant it happens.

def tool_search_github(query: str, max_results: int = 3) -> str {
    emit({"t": "tool", "name": "search_github", "arg": query, "phase": "call"});
    out = search_github(query, max_results);
    emit({"t": "tool", "name": "search_github", "phase": "return", "size": len(out)});
    return out;
}
sem tool_search_github = "Search GitHub for open-source projects matching a query. Returns repo names, descriptions and star counts. Call this to find prior art.";
sem tool_search_github.query = "Keywords describing the project or problem area.";
sem tool_search_github.max_results = "How many repositories to return. 3 is usually enough.";

def tool_describe_tech_stack(project_description: str) -> str {
    emit({"t": "tool", "name": "describe_tech_stack", "arg": project_description, "phase": "call"});
    out = describe_tech_stack(project_description);
    emit({"t": "tool", "name": "describe_tech_stack", "phase": "return", "size": len(out)});
    return out;
}
sem tool_describe_tech_stack = "Recommend the best tech stack for a project. Call this before advising on implementation.";
sem tool_describe_tech_stack.project_description = "What the project does, in a sentence or two.";

def tool_estimate_build_time(description: str, team_size: int = 2) -> str {
    emit({"t": "tool", "name": "estimate_build_time", "arg": description, "phase": "call"});
    out = estimate_build_time(description, team_size);
    emit({"t": "tool", "name": "estimate_build_time", "phase": "return", "size": len(out)});
    return out;
}
sem tool_estimate_build_time = "Estimate how long this project realistically takes to build at a hackathon. Call this to judge feasibility.";
sem tool_estimate_build_time.description = "What the project does and roughly how big it is.";
sem tool_estimate_build_time.team_size = "Number of people building it. Default 2.";

# ── Typed contracts ───────────────────────────────────────────────────────────

# Each capability documents itself on the enum member. The planner's own `sem`
# stays short because the meaning of each option lives here — one place, and the
# same place the `Act` stage routes on.
enum Capability { BRAINSTORM, STRUCTURE, RESEARCH, MENTORS }

sem Capability.BRAINSTORM = "Invent new candidate project ideas. Use when the user has no idea yet or wants alternatives.";
sem Capability.STRUCTURE = "Turn a rough idea into a formal pitch with problem, solution, stack and wow factor.";
sem Capability.RESEARCH = "Look up similar open-source projects, recommend a tech stack, and judge 24-48h feasibility.";
sem Capability.MENTORS = "Get concrete build advice from the most relevant domain experts.";

obj Intent {
    has goal: str;
    has topic: str;
    has is_smalltalk: bool;
}

sem Intent.goal = "One line stating what the user actually wants from this turn.";
sem Intent.topic = "A short SPECIFIC name for the project under discussion, e.g. 'study partner matching app'. Never a generic phrase like 'hackathon project'. Empty if no concrete project has come up yet.";
sem Intent.is_smalltalk = "True for greetings, thanks, or questions about the agent itself rather than about a project.";

obj Plan {
    has capabilities: list[Capability];
    has rationale: str;
}

sem Plan.capabilities = "The minimum set of capabilities this turn genuinely needs. Prefer fewer. Empty if the answer needs no extra work.";
sem Plan.rationale = "One short sentence explaining the choice.";

obj Pitch {
    has title: str;
    has problem: str;
    has solution: str;
    has tech_stack: list[str];
    has wow_factor: str;
}

sem Pitch.title = "A short, catchy project name.";
sem Pitch.problem = "The problem this solves, in one or two sentences.";
sem Pitch.solution = "How the project solves it.";
sem Pitch.tech_stack = "Concrete languages, frameworks and APIs to build it with.";
sem Pitch.wow_factor = "The one thing that makes a judge look up.";

# Mutable run state threaded through the stages. Passed by reference into each
# stage walker, so a stage's writes are visible to everything downstream.
obj RunCtx {
    has message: str;
    has history: str;
    has goal: str = "";
    has topic: str = "";
    has smalltalk: bool = False;
    has plan_caps: list[str] = [];
    has rationale: str = "";
    has findings: list[str] = [];
    has notes: list[dict] = [];   # trace from the stage just executed
}

# ── The cognition itself ──────────────────────────────────────────────────────

def:pub read_intent(message: str, history: str) -> Intent by llm();
sem read_intent = "Work out what the user actually wants from this turn, reading their message in the context of the conversation so far.";
sem read_intent.message = "The user's latest message.";
sem read_intent.history = "The conversation so far, oldest first. May be empty on the first turn.";

def:pub make_plan(goal: str, topic: str, history: str) -> Plan by llm();
sem make_plan = "Decide which capabilities this turn needs. Choose only what the request genuinely requires.";
sem make_plan.goal = "What the user wants, as read by the previous stage.";
sem make_plan.topic = "The project under discussion, or empty if none yet.";
sem make_plan.history = "The conversation so far, for judging what has already been covered.";

def:pub do_brainstorm(goal: str, history: str) -> str by llm();
sem do_brainstorm = "Invent 3 hackathon project ideas that fit what the user asked for. Give each a catchy name and one sentence. Each must be feasible in 24 hours.";
sem do_brainstorm.goal = "The kind of project the user is looking for.";
sem do_brainstorm.history = "Earlier conversation, so the ideas do not repeat what was already suggested.";

def:pub do_structure(topic: str, history: str) -> Pitch by llm();
sem do_structure = "Turn the idea under discussion into a structured pitch.";
sem do_structure.topic = "The project to formalise.";
sem do_structure.history = "Earlier conversation, for details the user already gave.";

def:pub do_research(topic: str) -> str by llm(
    tools=[tool_search_github, tool_describe_tech_stack, tool_estimate_build_time]
);
sem do_research = "Research the project and report back: similar open-source projects, a recommended tech stack, and an honest 24-48h feasibility call. Use the tools rather than guessing.";
sem do_research.topic = "The project to research.";

def:pub pick_mentors(subject: str) -> list[str] by llm();
sem pick_mentors = "Choose the two most relevant mentor domains, from exactly: Web Dev, Mobile, AI/ML, Game Dev, Jac Expert.";
sem pick_mentors.subject = "The project the mentors will advise on.";

def:pub do_advise(topic: str, mentor: str) -> str by llm();
sem do_advise = "Give 3 concrete next steps for building this project, in the voice of the named domain mentor. Be specific and practical.";
sem do_advise.topic = "The project to advise on.";
sem do_advise.mentor = "Which domain expert is speaking, e.g. 'AI/ML'.";

def:pub compose(message: str, history: str, findings: str) -> str by llm(stream=True);
sem compose = "Reply to the user conversationally and directly, in markdown. Be warm and concise; use short lists where they help.";
sem compose.message = "The user's message to answer.";
sem compose.history = "The conversation so far, for continuity and tone.";
sem compose.findings = "Work the agent already did this turn. Weave it in as if you had done it yourself — never mention findings, stages, capabilities or any internal machinery. May be empty, in which case just answer naturally.";

# ── The graph ─────────────────────────────────────────────────────────────────

node AgentPipeline {
    has version: str = "1";
}

node Stage {
    has key: str;
    has label: str;
    has blurb: str;
    has ord: int;
}

node CapabilityNode {
    has key: str;
    has label: str;
    has blurb: str;
    has pattern: str;   # which of the four patterns this capability demonstrates
}

# ── Stage behaviour ───────────────────────────────────────────────────────────

walker StageExec {
    has ctx: RunCtx;

    can think with Stage entry {
        self.ctx.notes = [];
        if here.key == "perceive" {
            intent = read_intent(self.ctx.message, self.ctx.history);
            self.ctx.goal = intent.goal;
            self.ctx.smalltalk = intent.is_smalltalk;
            if intent.topic { self.ctx.topic = intent.topic; }
            self.ctx.notes = [
                {"label": "goal", "value": intent.goal},
                {"label": "topic", "value": intent.topic if intent.topic else "—"}
            ];
        } elif here.key == "plan" {
            if self.ctx.smalltalk {
                self.ctx.plan_caps = [];
                self.ctx.rationale = "Conversational turn — no capabilities needed.";
            } else {
                plan = make_plan(self.ctx.goal, self.ctx.topic, self.ctx.history);
                self.ctx.plan_caps = [cap_key(c) for c in plan.capabilities];
                self.ctx.rationale = plan.rationale;
            }
            self.ctx.notes = [
                {"label": "selected",
                 "value": ", ".join(self.ctx.plan_caps) if self.ctx.plan_caps else "none"},
                {"label": "why", "value": self.ctx.rationale}
            ];
        }
    }
}

# ── Capability behaviour — one ability per capability ─────────────────────────

walker CapabilityExec {
    has ctx: RunCtx;
    has summary: str = "";

    can brainstorm with CapabilityNode entry {
        if here.key != "brainstorm" { return; }
        out = do_brainstorm(self.ctx.goal, self.ctx.history);
        self.ctx.findings += ["Ideas generated:\n" + out];
        self.summary = "3 ideas";
    }

    can structure with CapabilityNode entry {
        if here.key != "structure" { return; }
        p = do_structure(subject_of(self.ctx), self.ctx.history);
        if not self.ctx.topic { self.ctx.topic = p.title; }
        self.ctx.findings += [
            "Structured pitch:\ntitle: " + p.title + "\nproblem: " + p.problem
            + "\nsolution: " + p.solution + "\ntech: " + ", ".join(p.tech_stack)
            + "\nwow: " + p.wow_factor
        ];
        self.summary = p.title;
    }

    can research with CapabilityNode entry {
        if here.key != "research" { return; }
        out = do_research(subject_of(self.ctx));
        self.ctx.findings += ["Research:\n" + out];
        self.summary = "github + stack + feasibility";
    }

    can mentors with CapabilityNode entry {
        if here.key != "mentors" { return; }
        subject = subject_of(self.ctx);
        picked = pick_mentors(subject);
        advice: list[str] = [];
        for m in picked {
            emit({"t": "tool", "name": "mentor", "arg": m, "phase": "call"});
            advice.append(m + " mentor:\n" + do_advise(subject, m));
            emit({"t": "tool", "name": "mentor", "arg": m, "phase": "return", "size": 0});
        }
        self.ctx.findings += ["Mentor advice:\n" + "\n\n".join(advice)];
        self.summary = ", ".join(picked);
    }
}

"""What the capabilities actually work on: the concrete project if we have one,
otherwise the goal we read off this turn, otherwise the raw message."""
def subject_of(ctx: RunCtx) -> str {
    if ctx.topic { return ctx.topic; }
    return ctx.goal if ctx.goal else ctx.message;
}

def cap_key(c: Capability) -> str {
    if c == Capability.BRAINSTORM { return "brainstorm"; }
    if c == Capability.STRUCTURE { return "structure"; }
    if c == Capability.RESEARCH { return "research"; }
    return "mentors";
}

# ── Graph construction ────────────────────────────────────────────────────────

def ensure_agent_graph() -> AgentPipeline {
    found = [root-->][?:AgentPipeline];
    if found { return found[0]; }

    p = AgentPipeline();
    root ++> p;

    s1 = Stage(key="perceive", label="Perceive", ord=1,
               blurb="Read the message in context and extract a typed Intent.");
    s2 = Stage(key="plan", label="Plan", ord=2,
               blurb="Choose the minimum set of capabilities as a typed Plan.");
    s3 = Stage(key="act", label="Act", ord=3,
               blurb="Run only the capabilities the plan selected.");
    s4 = Stage(key="synthesize", label="Synthesize", ord=4,
               blurb="Compose one answer and stream it token by token.");
    p ++> s1;
    s1 ++> s2 ++> s3 ++> s4;

    # Capabilities hang off Act — adding one here is the entire change.
    s3 ++> CapabilityNode(key="brainstorm", label="Brainstorm", pattern="Generate",
        blurb="Invent candidate project ideas.");
    s3 ++> CapabilityNode(key="structure", label="Structure", pattern="Extract",
        blurb="Turn an idea into a typed pitch.");
    s3 ++> CapabilityNode(key="research", label="Research", pattern="Invoke",
        blurb="Search GitHub, pick a stack, estimate build time.");
    s3 ++> CapabilityNode(key="mentors", label="Mentors", pattern="Route + Spawn",
        blurb="Ask the most relevant domain experts.");
    return p;
}

# ── Conversation memory, persisted in the graph ───────────────────────────────

node ChatSession {}

node Turn {
    has role: str;
    has text: str;
}

def ensure_session() -> ChatSession {
    found = [root-->][?:ChatSession];
    if found { return found[0]; }
    s = ChatSession();
    root ++> s;
    return s;
}

def transcript(limit: int = 8) -> str {
    turns = [ensure_session()-->][?:Turn];
    recent = turns[-limit:] if len(turns) > limit else turns;
    return "\n".join([t.role + ": " + t.text for t in recent]);
}

def:pub agent_history() -> list[dict] {
    return [{"role": t.role, "text": t.text} for t in [ensure_session()-->][?:Turn]];
}

def:pub agent_reset() -> dict {
    for s in [root-->][?:ChatSession] {
        for t in [s-->][?:Turn] { del t; }
        del s;
    }
    return {"ok": True};
}

# ── Architecture introspection — the UI draws THIS ────────────────────────────

def:pub agent_architecture() -> dict {
    p = ensure_agent_graph();
    spine: list[dict] = [];
    cur = [p-->][?:Stage];
    while cur {
        st = cur[0];
        spine.append({
            "key": st.key, "label": st.label, "blurb": st.blurb, "ord": st.ord,
            "capabilities": [
                {"key": c.key, "label": c.label, "blurb": c.blurb, "pattern": c.pattern}
                for c in [st-->][?:CapabilityNode]
            ]
        });
        cur = [st-->][?:Stage];
    }
    return {"stages": spine};
}

# ── Worker: runs one capability so the endpoint can drain the bus live ────────
# Takes no arguments — nothing crosses the `flow` boundary (E1308), so the
# worker resolves its own node from the graph by key.

"""Walk the spine to find a capability — they hang off Act, not off the anchor."""
def find_capability(key: str) -> CapabilityNode | None {
    cur = [ensure_agent_graph()-->][?:Stage];
    while cur {
        st = cur[0];
        for c in [st-->][?:CapabilityNode] {
            if c.key == key { return c; }
        }
        cur = [st-->][?:Stage];
    }
    return None;
}

def run_capability() -> None {
    try {
        key = SLOT["cap_key"] as str;
        ctx = SLOT["ctx"] as RunCtx;
        cap = find_capability(key);
        if cap is None {
            raise ValueError("no capability node named " + key);
        }
        w = cap spawn CapabilityExec(ctx=ctx);
        SLOT["summary"] = w.summary;
    } except Exception as e {
        SLOT["error"] = str(e);
        emit({"t": "error", "msg": str(e)});
    } finally {
        emit({"t": "__end__"});
    }
}

# ── Transport: walk the graph, turn what happens into SSE frames ──────────────

def:pub agent_chat_stream(message: str) -> Generator {
    def stream -> Generator[str, None, None] {
        p = ensure_agent_graph();
        session = ensure_session();
        ctx = RunCtx(message=message, history=transcript());
        session ++> Turn(role="user", text=message);

        answer = "";
        try {
            stages = [p-->][?:Stage];
            while stages {
                st = stages[0];
                yield json.dumps({"t": "stage", "id": st.key, "status": "active"});

                if st.key == "act" {
                    for cap in [st-->][?:CapabilityNode] {
                        if cap.key not in ctx.plan_caps {
                            yield json.dumps({"t": "cap", "id": cap.key, "status": "skipped"});
                            continue;
                        }
                        yield json.dumps({"t": "cap", "id": cap.key, "status": "active"});

                        SLOT["cap_key"] = cap.key;
                        SLOT["ctx"] = ctx;
                        SLOT["summary"] = "";
                        task = flow run_capability();

                        draining = True;
                        while draining {
                            ev = BUS.get();
                            if ev["t"] == "__end__" { draining = False; continue; }
                            ev["cap"] = cap.key;
                            yield json.dumps(ev);
                        }
                        wait task;

                        yield json.dumps({
                            "t": "cap", "id": cap.key, "status": "done",
                            "detail": SLOT["summary"]
                        });
                    }
                } elif st.key == "synthesize" {
                    for tok in compose(message, ctx.history, "\n\n".join(ctx.findings)) {
                        answer += str(tok);
                        yield json.dumps({"t": "token", "v": str(tok)});
                    }
                } else {
                    st spawn StageExec(ctx=ctx);
                    for n in ctx.notes {
                        yield json.dumps({
                            "t": "note", "id": st.key,
                            "label": n["label"], "value": n["value"]
                        });
                    }
                }

                yield json.dumps({"t": "stage", "id": st.key, "status": "done"});
                stages = [st-->][?:Stage];
            }
        } except Exception as e {
            yield json.dumps({"t": "error", "msg": str(e)});
        }

        if answer {
            session ++> Turn(role="assistant", text=answer);
        }
        yield json.dumps({"t": "final"});
    }
    report stream();
}
