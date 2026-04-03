"""Step 1: Generate — the `by llm()` primitive.
The function signature (name + params + return type + docstring) IS the prompt.
No function body needed — the LLM fills it in at runtime.

Run: jac run step1_generate.jac
"""

def brainstorm_ideas(interests: str, skills: str) -> str by llm();

sem brainstorm_ideas = "Brainstorm 3 creative hackathon project ideas based on the person's interests and skills. For each idea give it a catchy name and a one-sentence description. Make them fun, feasible in 24 hours, and genuinely useful.";

with entry {
    ideas = brainstorm_ideas(
        interests="music, coffee, sustainability",
        skills="Python, React"
    );
    print("=== Step 1: Generate ===\n");
    print(ideas);
}
