"""Step 2: Extract — Mind Primitive
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Same as Generate, but the return type is a typed object instead of str.
The compiler enforces the schema — the LLM *cannot* return malformed data.
No more JSON parsing, no more "parse and pray."

Pattern:
    obj MySchema {
        has field1: str;
        has field2: list[str];
        has category: SomeEnum;
    }

    def extract(input: str) -> MySchema by llm();

The LLM sees the schema and fills every field. Your code gets a real object.
"""

import from tools { save_md }

# ── Define the schema ──────────────────────────────────────────────────────────

enum Difficulty { BEGINNER, INTERMEDIATE, ADVANCED }

enum Track { WEB, MOBILE, AI_ML, GAME, OTHER }

obj HackathonPitch {
    has title: str;
    has problem: str;           # One sentence: what pain does this solve?
    has solution: str;          # One sentence: what does the app do?
    has tech_stack: list[str];  # e.g. ["Python", "Flask", "Spotify API"]
    has wow_factor: str;        # The one thing that makes judges say "whoa"
    has difficulty: Difficulty;
    has track: Track;
}

# ── The primitive ──────────────────────────────────────────────────────────────

def:pub structure_pitch(raw_idea: str) -> HackathonPitch by llm();
sem structure_pitch = "Turn a raw hackathon idea into a structured, compelling pitch with a title, problem statement, solution, tech stack, wow factor, difficulty, and track.";


# ── Run it ─────────────────────────────────────────────────────────────────────
with entry {
    # Paste in the output from Step 1, or just describe your idea:
    raw_idea = """
    An app that listens to the music you're playing and automatically generates
    a lo-fi focus playlist that matches the vibe. Uses Spotify API and some
    mood detection. Could sync with your Google Calendar to kick in before exams.
    """;

    pitch = structure_pitch(raw_idea);

    print(f"Title:       {pitch.title}");
    print(f"Track:       {pitch.track}");
    print(f"Difficulty:  {pitch.difficulty}");
    print(f"Problem:     {pitch.problem}");
    print(f"Solution:    {pitch.solution}");
    print(f"Wow Factor:  {pitch.wow_factor}");
    print(f"Tech Stack:  {', '.join(pitch.tech_stack)}");

    contribs = "\n".join([f"- {t}" for t in pitch.tech_stack]);
    md = f"""# Step 2: Extract

## {pitch.title}
**Track:** {pitch.track} | **Difficulty:** {pitch.difficulty}

### Problem
{pitch.problem}

### Solution
{pitch.solution}

### Wow Factor
{pitch.wow_factor}

### Tech Stack
{contribs}
""";
    save_md("step2_extract.md", md);
}
