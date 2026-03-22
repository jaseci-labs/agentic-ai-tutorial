"""Step 3: Invoke — Mind primitive.
Give the LLM functions it can call. It decides which to use,
inspects results, and keeps going until it has a complete answer.
Invoke carries an implicit Loop (the ReAct cycle): the LLM
reasons about which tool to call, acts, and observes the result.

Primitive: Invoke (LLM → tool calls)
Builds on: Generate (Step 1)"""

import from tools { search_papers, get_citations, summarize_abstract }

# The LLM decides which tools to call and in what order.
# by llm(tools=[...]) enables the ReAct cycle: reason → act → observe → repeat.
def research(query: str) -> str by llm(
    tools=[search_papers, get_citations, summarize_abstract]
);
sem research = "Research a topic by searching papers, checking citations, and summarizing findings.";

with entry {
    result = research("Find recent papers on transformer architectures and their citation impact");
    print(result);
}
