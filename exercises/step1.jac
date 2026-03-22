"""Exercise 1: Generate — Mind primitive.
The simplest agentic primitive: delegate a function to the LLM.
The function signature IS the prompt. LLM returns free text.

Primitive: Generate (LLM -> free text)

YOUR TASK:
  Define a function `answer` that takes a question and returns free text
  by delegating to the LLM.

HINT: Look at solutions/step1_generate.jac if you get stuck.
"""

import from tools { save_md }

# TODO: Define an `answer` function that:
#   - Takes a question (str) as input
#   - Returns a str
#   - Delegates to the LLM using `by llm()`
#
# Example pattern:
#   """Docstring describing what the function does."""
#   def my_func(input: str) -> str by llm();



with entry {
    response = answer("What are three interesting facts about computer architecture?");
    print(response);

    # Save output as markdown
    md = f"# Step 1: Generate\n\n## Question\nWhat are three interesting facts about computer architecture?\n\n## Answer\n{response}\n";
    save_md("step1_generate.md", md);
}
