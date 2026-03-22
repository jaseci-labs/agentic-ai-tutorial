"""Step 1: Generate — Mind primitive.
The simplest agentic primitive: delegate a function to the LLM.
The function signature IS the prompt. LLM returns free text.

Primitive: Generate (LLM → free text)"""

"""Answer a question about any topic."""
def answer(question: str) -> str by llm();

with entry {
    response = answer("What are three interesting facts about computer architecture?");
    print(response);
}
