"""Step 1: Generate — Mind primitive.
The simplest agentic primitive: delegate a function to the LLM.
The function signature IS the prompt. LLM returns free text.

Primitive: Generate (LLM -> free text)"""

import from tools { save_md }

"""Answer a question about any topic."""
def answer(question: str) -> str by llm();

with entry {
    response = answer("What are three interesting facts about computer architecture?");
    print(response);

    md = f"# Step 1: Generate\n\n## Question\nWhat are three interesting facts about computer architecture?\n\n## Answer\n{response}\n";
    save_md("step1_generate.md", md);
}
