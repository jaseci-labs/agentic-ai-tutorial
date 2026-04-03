"""Step 3: Invoke — `by llm(tools=[...])`.
Give the LLM callable functions. It runs a ReAct loop:
reason → call tool → observe result → repeat until done.

Run: jac run step3_invoke.jac
"""

import from tools { search_github, describe_tech_stack, estimate_build_time }

def research_idea(idea: str) -> str by llm(
    tools=[search_github, describe_tech_stack, estimate_build_time]
);

sem research_idea = "Research a hackathon project idea thoroughly before answering. Use the tools to find real data.";

with entry {
    result = research_idea(
        "AI-powered accessibility tool that generates live captions for deaf users at events"
    );
    print("=== Step 3: Invoke ===\n");
    print(result);
}
