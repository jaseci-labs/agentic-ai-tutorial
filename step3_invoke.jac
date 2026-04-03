"""Step 3: Invoke — Mind Primitive
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Hand the LLM a list of tools. It decides which ones to call, inspects the
results, and keeps going until it has a complete answer. This is the ReAct loop:
    Reason → Act (call a tool) → Observe (read the result) → Reason → ...

The LLM stops when it's confident it has enough information.

Pattern:
    def my_agent(input: str) -> str by llm(tools=[tool_a, tool_b, tool_c]);
    sem my_agent = "What the agent should accomplish. Guides its reasoning.";

`sem` (semantic hint) is a one-line description attached to a function. The LLM
reads it to understand when/why to call the function — like a docstring for the
agent layer.
"""

import from tools { search_github, describe_tech_stack, estimate_build_time, save_md }

# ── The primitive ──────────────────────────────────────────────────────────────

def:pub research_idea(idea: str) -> str by llm(
    tools=[search_github, describe_tech_stack, estimate_build_time]
);
sem research_idea = "Research a hackathon project idea: find similar open-source projects on GitHub, recommend the right tech stack, and give an honest estimate of whether it's buildable in 24-48 hours with a small team.";


# ── Run it ─────────────────────────────────────────────────────────────────────
with entry {
    result = research_idea(
        "A Spotify-integrated app that detects your current music mood and "
        "generates a lo-fi study playlist, synced with your Google Calendar exam schedule"
    );

    print(result);
    save_md("step3_invoke.md", f"# Step 3: Invoke\n\n{result}\n");
}
