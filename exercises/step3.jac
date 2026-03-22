"""Exercise 3: Invoke — Mind primitive.
Give the LLM functions it can call. It decides which to use,
inspects results, and keeps going until it has a complete answer.
Invoke carries an implicit Loop (the ReAct cycle): the LLM
reasons about which tool to call, acts, and observes the result.

Primitive: Invoke (LLM -> tool calls)
Builds on: Generate (Step 1)

YOUR TASK:
  Define a function `research` that gives the LLM access to
  search_papers, get_citations, and summarize_abstract as tools.

HINT: Look at solutions/step3_invoke.jac if you get stuck.
"""

import from tools { search_papers, get_citations, summarize_abstract, save_md }

# TODO: Define a `research` function that:
#   - Takes a query (str) as input
#   - Returns a str
#   - Delegates to the LLM with tools: by llm(tools=[...])
#     Pass in: search_papers, get_citations, summarize_abstract
#
# Then add a semantic hint:
#   sem research = "Research a topic by searching papers, checking citations, and summarizing findings.";



with entry {
    result = research("Find recent papers on transformer architectures and their citation impact");
    print(result);

    # Save output as markdown
    md = f"# Step 3: Invoke\n\n## Query\nFind recent papers on transformer architectures and their citation impact\n\n## Research Results\n{result}\n";
    save_md("step3_invoke.md", md);
}
