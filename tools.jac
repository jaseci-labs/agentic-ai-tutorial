"""Shared tools for the Hackathon Pitch Builder agent.
These are regular Jac functions the LLM can call via the Invoke primitive (Step 3).

Jac pattern — tool functions are just normal functions:
    def my_tool(input: str) -> str { ... }          # regular function
    def llm_tool(input: str) -> str by llm();        # LLM-delegated function
    sem my_tool = "What this tool does (guides LLM).";
"""

import json;
import os;
import from urllib.request { urlopen, Request }
import from urllib.parse { quote }

# ── Real tool: hits the GitHub Search API (no auth needed for public search) ──
def search_github(query: str, max_results: int = 3) -> str {
    try {
        url = f"https://api.github.com/search/repositories?q={quote(query)}&sort=stars&per_page={max_results}";
        req = Request(url, headers={"User-Agent": "JacHacks/1.0", "Accept": "application/vnd.github.v3+json"});
        resp = json.loads(urlopen(req, timeout=10).read().decode());
        repos: list = [];
        for item in resp.get("items", []) {
            repos.append({
                "name": item["full_name"],
                "description": item.get("description", "No description"),
                "stars": item["stargazers_count"],
                "url": item["html_url"]
            });
        }
        return json.dumps(repos, indent=2);
    } except Exception as e {
        return f"GitHub search failed: {e}";
    }
}

# ── LLM-delegated tools: no external API needed, LLM answers directly ─────────
def describe_tech_stack(project_description: str) -> str by llm();
def estimate_build_time(description: str, team_size: int = 2) -> str by llm();

# ── Utility ────────────────────────────────────────────────────────────────────
def save_md(filename: str, content: str) {
    os.makedirs("output", exist_ok=True);
    f = open(f"output/{filename}", "w");
    f.write(content);
    f.close();
    print(f"\n>> Saved to output/{filename}");
}

# Semantic hints tell the LLM *when* and *why* to call each tool
sem search_github = "Search GitHub for open-source projects matching a query. Returns repo names, descriptions, and star counts. Use this to find similar projects or inspiration.";
sem describe_tech_stack = "Describe the best tech stack (languages, frameworks, APIs) for a project type. Call this when you need to recommend implementation tools.";
sem estimate_build_time = "Estimate how long a project would realistically take to build at a hackathon given the description and team size. Be honest about scope. Call this to assess 24-48 hour feasibility.";
