"""Shared presentational pieces for the guided build — no state, no server calls.

Styling is Tailwind utility classes. Tailwind only generates CSS for class names
it can see whole in the source, so an accent is looked up here as complete
strings — never assembled as "text-" + name.
"""

import from "react-markdown" { default as ReactMarkdown }
import from "remark-gfm" { default as remarkGfm }

# One accent per pattern: gen(erate), ext(ract), inv(oke), r(ou)te.
glob ACCENT: dict[str, dict[str, str]] = {
    "gen": {
        "num": "border-gen/40 bg-gen/10 text-gen",
        "card": "border-gen/25",
        "btn": "bg-gen hover:bg-gen/85 focus-visible:outline-gen"
    },
    "ext": {
        "num": "border-ext/40 bg-ext/10 text-ext",
        "card": "border-ext/25",
        "btn": "bg-ext hover:bg-ext/85 focus-visible:outline-ext"
    },
    "inv": {
        "num": "border-inv/40 bg-inv/10 text-inv",
        "card": "border-inv/25",
        "btn": "bg-inv hover:bg-inv/85 focus-visible:outline-inv"
    },
    "rte": {
        "num": "border-rte/40 bg-rte/10 text-rte",
        "card": "border-rte/25",
        "btn": "bg-rte hover:bg-rte/85 focus-visible:outline-rte"
    }
};

glob STATUS_PILL: dict[str, str] = {
    "ready": "border-line bg-panel-2 text-dim",
    "running": "border-brand/40 bg-brand/10 text-gen",
    "done": "border-ok/30 bg-ok/10 text-ok",
    "locked": "border-line bg-transparent text-faint"
};

glob LABEL: str = "mb-1.5 block text-xs font-medium text-dim";

glob INPUT: str = "block w-full rounded-lg border border-line bg-canvas/60 px-3 py-2 text-sm text-fg placeholder:text-faint transition focus:border-line-strong focus:ring-2 focus:ring-brand/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-60";

# Separates a step's form from the result it produced.
glob RESULT: str = "mt-5 border-t border-line pt-5";

"""One step of the guided build: a numbered rail on the left, the card beside it.
`state` is "active", "done" or "locked"."""
def:pub StepCard(
    num: int,
    accent: str,
    title: str,
    subtitle: str,
    state: str,
    busy: bool,
    busyLabel: str = "running",
    last: bool = False,
    children: any = None
) -> JsxElement {
    tone = ACCENT[accent];
    status = "done" if state == "done" else ("running" if busy else ("locked" if state == "locked" else "ready"));
    status_text = "✓ done" if status == "done" else (busyLabel if status == "running" else status);
    num_cls = "border-ok/40 bg-ok/10 text-ok" if state == "done" else tone["num"];
    card_cls = tone["card"] if state == "active" else "border-line";

    return <section className={"grid grid-cols-[2.5rem_minmax(0,1fr)] gap-x-4 transition-opacity " + ("pointer-events-none opacity-45" if state == "locked" else "")}>
        <div className="flex flex-col items-center">
            <div className={"grid size-10 place-items-center rounded-full border text-sm font-semibold " + num_cls}>
                {"✓" if state == "done" else str(num)}
            </div>
            {not last and <div className="mt-2 w-px flex-1 bg-line"></div>}
        </div>

        <div className={"mb-8 min-w-0 rounded-2xl border bg-panel shadow-lg shadow-black/20 " + card_cls}>
            <header className="flex items-start gap-3 border-b border-line px-5 py-4">
                <div className="min-w-0 flex-1">
                    <h2 className="text-[15px] font-semibold tracking-tight text-fg">{title}</h2>
                    <p className="mt-0.5 text-sm text-dim">{subtitle}</p>
                </div>
                <span className={"shrink-0 rounded-full border px-2.5 py-0.5 text-xs font-medium " + STATUS_PILL[status]}>
                    {status_text}
                </span>
            </header>
            <div className="p-5">{children}</div>
        </div>
    </section>;
}

def:pub PrimaryButton(
    accent: str,
    disabled: bool,
    onClick: Callable[[], None],
    children: any = None
) -> JsxElement {
    return <button
        className={"inline-flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-semibold text-canvas shadow-sm transition focus-visible:outline-2 focus-visible:outline-offset-2 disabled:cursor-not-allowed disabled:opacity-40 " + ACCENT[accent]["btn"]}
        onClick={onClick}
        disabled={disabled}
    >
        {children}
    </button>;
}

"""Three bouncing dots, with an optional line saying what is being waited on."""
def:pub TypingDots(label: str = "") -> JsxElement {
    return <div className="flex items-center gap-3 text-xs text-dim">
        <span className="flex gap-1">
            <span className="size-1.5 animate-bounce rounded-full bg-dim"></span>
            <span className="size-1.5 animate-bounce rounded-full bg-dim [animation-delay:150ms]"></span>
            <span className="size-1.5 animate-bounce rounded-full bg-dim [animation-delay:300ms]"></span>
        </span>
        {label}
    </div>;
}

def:pub ErrorBanner(message: str) -> JsxElement {
    return <div className="rounded-lg border border-bad/30 bg-bad/10 px-3 py-2 text-sm break-words text-bad">
        {message}
    </div>;
}

"""LLM output is markdown; `.markdown` (styles.css) styles the bare elements.
remark-gfm adds the tables and strikethrough that models like to emit."""
def:pub Markdown(text: str) -> JsxElement {
    return <div className="markdown">
        <ReactMarkdown remarkPlugins={[remarkGfm]}>{text}</ReactMarkdown>
    </div>;
}
