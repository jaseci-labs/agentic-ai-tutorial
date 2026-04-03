"""Step 1: Generate — Mind Primitive
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The simplest agentic primitive. You write a function signature; the LLM fills in
the body. The function name, parameter names, return type, and docstring together
become the prompt — no prompt engineering needed.

Pattern:
    def my_func(param: type) -> str by llm();

That's it. One line.
"""

import from tools { save_md }

# ── The primitive ──────────────────────────────────────────────────────────────

def:pub brainstorm_ideas(interests: str, skills: str) -> str by llm();
sem brainstorm_ideas = "Brainstorm 3 creative hackathon project ideas based on the person's interests and skills. For each idea give it a catchy name and a one-sentence description. Make them fun, feasible in 24 hours, and genuinely useful.";


# ── Run it ─────────────────────────────────────────────────────────────────────
with entry {
    ideas = brainstorm_ideas(
        interests="music, helping students, social apps",
        skills="Python, a bit of web dev"
    );

    print(ideas);
    save_md("step1_generate.md", f"# Step 1: Generate\n\n{ideas}\n");
}
