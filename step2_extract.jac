"""Step 2: Extract — typed return from `by llm()`.
Same as Generate, but returns a typed obj instead of str.
The compiler enforces the schema — no JSON parsing, no "parse and pray."

Run: jac run step2_extract.jac
"""

enum Difficulty { BEGINNER, INTERMEDIATE, ADVANCED }
enum Track { WEB, MOBILE, AI_ML, GAME, OTHER }

obj HackathonPitch {
    has title: str;
    has problem: str;
    has solution: str;
    has tech_stack: list[str];
    has wow_factor: str;
    has difficulty: Difficulty;
    has track: Track;
}

def structure_pitch(raw_idea: str) -> HackathonPitch by llm();

sem structure_pitch = "Turn a raw hackathon idea into a structured, compelling pitch with a title, problem statement, solution, tech stack, wow factor, difficulty, and track.";

with entry {
    pitch = structure_pitch(
        "An app that matches leftover restaurant food with nearby shelters in real time"
    );
    print("=== Step 2: Extract ===\n");
    print(f"Title:       {pitch.title}");
    print(f"Problem:     {pitch.problem}");
    print(f"Solution:    {pitch.solution}");
    print(f"Tech stack:  {pitch.tech_stack}");
    print(f"Wow factor:  {pitch.wow_factor}");
    print(f"Difficulty:  {pitch.difficulty}");
    print(f"Track:       {pitch.track}");
}
