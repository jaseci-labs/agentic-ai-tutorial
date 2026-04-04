"""Step 4: Route + Spawn — `visit [-->] by llm()` + `flow spawn` + `wait`.
The LLM reads node descriptions and picks the best expert(s).
Each selected node flow-spawns a parallel AdviceWorker.
Walker collects all results by awaiting each with `wait`.

No if/else chains. The graph topology IS the routing table.

Run: jac run step4_route.jac
"""

# Worker walker — one per selected mentor, runs concurrently
walker AdviceWorker {
    has pitch: str;
    has mentor: str;
    has advice: str = "";

    can work with Root entry {
        self.advice = get_advice(self.pitch, self.mentor);
    }
}

def get_advice(pitch: str, mentor: str) -> str by llm();

sem get_advice = "Give practical next-step advice for building this hackathon project. Suggest 3-5 concrete first tasks.";

# Expert nodes — LLM reads `description` to decide which ones to visit
node WebDevMentor {
    has description: str = "Expert in web apps: React, APIs, databases, authentication, and full-stack deployment";

    can respond with HackathonAdvisor entry {
        t = flow root() spawn AdviceWorker(pitch=visitor.pitch, mentor="Web Dev");
        visitor.tasks = visitor.tasks + [t];
        visitor.mentors = visitor.mentors + ["Web Dev"];
    }
}

node MobileMentor {
    has description: str = "Expert in mobile apps: iOS, Android, React Native, Expo, and mobile UX";

    can respond with HackathonAdvisor entry {
        t = flow root() spawn AdviceWorker(pitch=visitor.pitch, mentor="Mobile");
        visitor.tasks = visitor.tasks + [t];
        visitor.mentors = visitor.mentors + ["Mobile"];
    }
}

node AIMLMentor {
    has description: str = "Expert in AI/ML: LLMs, embeddings, computer vision, and model APIs like OpenAI";

    can respond with HackathonAdvisor entry {
        t = flow root() spawn AdviceWorker(pitch=visitor.pitch, mentor="AI/ML");
        visitor.tasks = visitor.tasks + [t];
        visitor.mentors = visitor.mentors + ["AI/ML"];
    }
}

node GameDevMentor {
    has description: str = "Expert in game dev: Unity, Godot, Pygame, game design, and interactive experiences";

    can respond with HackathonAdvisor entry {
        t = flow root() spawn AdviceWorker(pitch=visitor.pitch, mentor="Game Dev");
        visitor.tasks = visitor.tasks + [t];
        visitor.mentors = visitor.mentors + ["Game Dev"];
    }
}

node CollectNode {}  # walker walks here after all mentor visits to await workers

walker HackathonAdvisor {
    has pitch: str;
    has tasks: list = [];    # flow spawn handles (awaited with `wait`)
    has mentors: list = [];  # parallel list: mentor name per task
    has results: list = [];

    can route with Root entry {
        # web     = WebDevMentor();
        # mob     = MobileMentor();
        # aiml    = AIMLMentor();
        # game    = GameDevMentor();
        collect = CollectNode();
        here ++> WebDevMentor() ++> collect;
        here ++> MobileMentor() ++> collect;
        here ++> AIMLMentor() ++> collect;
        here ++> GameDevMentor() ++> collect;
        # Route: LLM reads each node's description, visits the best match(es).
        # Each visited node flow-spawns an AdviceWorker — all run in parallel.
        visit [-->] by llm(incl_info={"Hackathon pitch": self.pitch});
        visit collect;
        
    }

    can collect with CollectNode entry {
        # Await each parallel worker and collect results
        for i in range(len(self.tasks)) {
            w = wait self.tasks[i];
            self.results = self.results + [{"mentor": self.mentors[i], "advice": w.advice}];
        }
    }
}

with entry {
    advisor = root() spawn HackathonAdvisor(
        pitch="A real-time multiplayer trivia game with AI-generated questions using WebSockets and React"
    );
    print("=== Step 4: Route + Spawn ===\n");
    for r in advisor.results {
        print(f"--- {r['mentor']} ---");
        print(r["advice"]);
        print("");
    }
}