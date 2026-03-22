"""Naive Python equivalent of step8_composition.jac

This file implements the SAME self-correcting parallel research agent
as step8_composition.jac — but WITHOUT Jac's 7 primitives.

Every line of boilerplate here corresponds to something Jac handles
declaratively. The primitives and what they save you from:

  Generate  — no `by llm()`: you write every API call, message list, role
  Extract   — no typed schema: you write JSON schema, parse, validate manually
  Invoke    — no tool dispatch: you write the tool-call loop, parse each call
  Route     — no `visit [-->] by llm()`: you write a routing prompt + parse list
  Spawn     — no `flow spawn`: you manage ThreadPoolExecutor + futures yourself
  Pipe      — no graph edges: you pass data explicitly through every function
  Loop      — no `while` sugar on LLM output: you reparse verdict each iteration

Run with:  python step8_composition_naive.py
Requires:  pip install openai
           export OPENAI_API_KEY=...
"""

import json
import threading
import concurrent.futures
from enum import Enum
from typing import Optional
from urllib.request import urlopen, Request
from urllib.parse import quote
from xml.etree.ElementTree import fromstring

from openai import OpenAI

client = OpenAI()
MODEL = "gpt-4o"

# ===========================================================================
# Tools (same logic as tools.jac — copied here because there's no import)
# ===========================================================================

def search_papers(query: str, max_results: int = 3) -> str:
    try:
        url = (f"http://export.arxiv.org/api/query"
               f"?search_query=all:{quote(query)}&max_results={max_results}")
        resp = urlopen(url, timeout=10).read().decode()
        xml_root = fromstring(resp)
        ns = {"atom": "http://www.w3.org/2005/Atom"}
        papers = []
        for entry in xml_root.findall("atom:entry", ns):
            title = entry.find("atom:title", ns).text.strip()
            abstract = entry.find("atom:summary", ns).text.strip()
            papers.append({"title": title, "abstract": abstract})
        return json.dumps(papers, indent=2)
    except Exception as e:
        return f"Search failed: {e}"


def get_citations(paper_title: str) -> str:
    try:
        url = (f"https://api.openalex.org/works"
               f"?search={quote(paper_title)}&per_page=1"
               f"&select=title,cited_by_count")
        req = Request(url, headers={"User-Agent": "NaivePython/1.0"})
        resp = json.loads(urlopen(req, timeout=10).read().decode())
        if resp.get("results"):
            paper = resp["results"][0]
            return f"{paper['title']} has been cited {paper['cited_by_count']} times."
        return f"No citation data found for '{paper_title}'."
    except Exception as e:
        return f"Citation lookup failed: {e}"


# ---------------------------------------------------------------------------
# Tool registry — Jac builds this automatically from `tools=[...]` on `by llm()`
# ---------------------------------------------------------------------------
TOOL_FUNCTIONS = {
    "search_papers": search_papers,
    "get_citations": get_citations,
}

# OpenAI tool schema — Jac infers this from docstrings / `sem` annotations.
# Here you must write it by hand.
TOOL_SCHEMAS = [
    {
        "type": "function",
        "function": {
            "name": "search_papers",
            "description": "Search for academic papers matching a query. Returns titles and abstracts.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Search query"},
                    "max_results": {"type": "integer", "default": 3},
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_citations",
            "description": "Get citation count for a paper by title.",
            "parameters": {
                "type": "object",
                "properties": {
                    "paper_title": {"type": "string"},
                },
                "required": ["paper_title"],
            },
        },
    },
]


# ===========================================================================
# Primitive 3 — INVOKE (tool-call loop)
# Jac:  `def investigate(topic: str) -> str by llm(tools=[search_papers, ...])`
# Here: you write the multi-turn tool-execution loop yourself.
# ===========================================================================
def llm_with_tools(system_prompt: str, user_prompt: str) -> str:
    """Run an LLM call that may invoke tools — returns the final text reply."""
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user",   "content": user_prompt},
    ]

    while True:
        response = client.chat.completions.create(
            model=MODEL,
            messages=messages,
            tools=TOOL_SCHEMAS,
            tool_choice="auto",
        )
        msg = response.choices[0].message

        # If no tool calls, we're done
        if not msg.tool_calls:
            return msg.content or ""

        # Append assistant turn with tool_calls
        messages.append({
            "role": "assistant",
            "content": msg.content,
            "tool_calls": [
                {
                    "id": tc.id,
                    "type": "function",
                    "function": {
                        "name": tc.function.name,
                        "arguments": tc.function.arguments,
                    },
                }
                for tc in msg.tool_calls
            ],
        })

        # Execute each tool call and append its result
        for tc in msg.tool_calls:
            fn_name = tc.function.name
            fn_args = json.loads(tc.function.arguments)
            if fn_name not in TOOL_FUNCTIONS:
                result = f"Unknown tool: {fn_name}"
            else:
                result = TOOL_FUNCTIONS[fn_name](**fn_args)

            messages.append({
                "role": "tool",
                "tool_call_id": tc.id,
                "content": result,
            })
        # Loop: send tool results back to the model


# ===========================================================================
# Primitive 1 — GENERATE
# Jac:  `def write_survey(...) -> str by llm()`
# Here: you manually build messages, call the API, extract .content
# ===========================================================================
def llm_generate(system_prompt: str, user_prompt: str) -> str:
    response = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user",   "content": user_prompt},
        ],
    )
    return response.choices[0].message.content or ""


# ===========================================================================
# Primitive 2 — EXTRACT (structured output)
# Jac:  `def review_survey(...) -> SurveyReview by llm()`
#       where SurveyReview is a typed obj with enum Verdict
# Here: you write the JSON schema, call response_format, parse + validate manually
# ===========================================================================

# The enum and dataclass Jac derives automatically from typed obj / enum declarations
class Verdict(str, Enum):
    PUBLISH_READY = "PUBLISH_READY"
    NEEDS_REVISION = "NEEDS_REVISION"

# Manually written JSON schema (Jac generates this from the obj definition)
SURVEY_REVIEW_SCHEMA = {
    "type": "json_schema",
    "json_schema": {
        "name": "SurveyReview",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {
                "verdict": {
                    "type": "string",
                    "enum": ["PUBLISH_READY", "NEEDS_REVISION"],
                },
                "coverage_gaps": {
                    "type": "array",
                    "items": {"type": "string"},
                },
                "suggestions": {
                    "type": "array",
                    "items": {"type": "string"},
                },
            },
            "required": ["verdict", "coverage_gaps", "suggestions"],
            "additionalProperties": False,
        },
    },
}


def llm_extract_review(system_prompt: str, user_prompt: str) -> dict:
    """Structured extraction — returns parsed dict with verdict/gaps/suggestions."""
    response = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user",   "content": user_prompt},
        ],
        response_format=SURVEY_REVIEW_SCHEMA,
    )
    raw = response.choices[0].message.content or "{}"
    data = json.loads(raw)
    # Manual validation — Jac does this automatically via the typed obj
    assert "verdict" in data and "coverage_gaps" in data and "suggestions" in data, \
        f"Malformed LLM response: {data}"
    data["verdict"] = Verdict(data["verdict"])
    return data


# ===========================================================================
# Primitive 4 — ROUTE
# Jac:  `visit [-->] by llm(incl_info={"Research topic": self.topic})`
#       The LLM reads each node's description and picks which to visit.
# Here: you write a selection prompt, parse a JSON list, guard against
#       hallucinated names, and manually dispatch to the right branch.
# ===========================================================================

TRACKS = {
    "hardware": "Hardware architecture track: cache, memory, accelerators, PIM",
    "systems":  "Systems software track: OS, compilers, runtime, scheduling",
    "ml":       "ML algorithms track: training, inference, model architecture",
}

def route_tracks(topic: str) -> list[str]:
    """Ask the LLM which research tracks are relevant; return validated list."""
    track_descriptions = "\n".join(
        f'  "{k}": {v}' for k, v in TRACKS.items()
    )
    # Without Jac's `visit [-->] by llm(incl_info=...)`, you must manually:
    #   - explain the routing task
    #   - list every candidate with its description
    #   - specify the exact output format (or risk free-text answers)
    #   - give a concrete example (models hallucinate without one)
    #   - remind the model not to invent new keys
    #   - remind the model not to wrap output in markdown
    prompt = (
        f"You are a research planning assistant responsible for routing an incoming "
        f"research topic to the correct specialist tracks. Your routing decision "
        f"determines which domain experts will be activated, so accuracy matters.\n\n"
        f"Research topic: '{topic}'\n\n"
        f"Below are all available research tracks. Each track has a unique key and "
        f"a description of the subject areas it covers:\n\n"
        f"{track_descriptions}\n\n"
        f"Routing instructions:\n"
        f"  1. Read the research topic carefully and identify its core subject areas.\n"
        f"  2. For each track, assess whether its described subject areas overlap "
        f"     meaningfully with the research topic.\n"
        f"  3. Apply an inclusive routing policy: if a track is even tangentially "
        f"     relevant, include it. It is better to over-route than to miss a "
        f"     relevant perspective.\n"
        f"  4. You MUST select at least one track. If you are uncertain, select all.\n"
        f"  5. You may only use the exact keys shown above — do not invent, shorten, "
        f"     or rephrase any key.\n\n"
        f"Output format:\n"
        f"  - Return a single raw JSON array containing the selected keys.\n"
        f"  - Do NOT wrap the array in markdown backticks or a code block.\n"
        f"  - Do NOT add any prose, explanation, or commentary before or after.\n"
        f"  - The array must be parseable by Python's json.loads() with no cleanup.\n\n"
        f"Examples (for illustration only — do not copy these verbatim):\n"
        f"  Topic: 'quantization of transformer weights for edge inference'\n"
        f"  Output: [\"hardware\", \"ml\"]\n\n"
        f"  Topic: 'OS-level memory management for GPU training jobs'\n"
        f"  Output: [\"hardware\", \"systems\"]\n\n"
        f"Now produce your output for the research topic above:"
    )
    raw = llm_generate(
        system_prompt=(
            "You are a research routing agent. Your only job is to select which "
            "research tracks are relevant to a given topic. "
            "You must output ONLY a raw JSON array of string keys with no surrounding "
            "text, no markdown, and no explanation. Any output that is not a valid "
            "JSON array will be treated as a routing failure."
        ),
        user_prompt=prompt,
    )
    # Strip markdown fences if present — Jac never has to deal with this
    raw = raw.strip().strip("```json").strip("```").strip()
    try:
        selected = json.loads(raw)
    except json.JSONDecodeError:
        # Fallback: include all tracks if parsing fails
        print(f"  [Route] Failed to parse LLM response, selecting all tracks: {raw}")
        selected = list(TRACKS.keys())

    # Validate — Jac type-checks this automatically
    valid = [k for k in selected if k in TRACKS]
    if not valid:
        valid = list(TRACKS.keys())
    return valid


# ===========================================================================
# Primitive 5 — SPAWN (parallel sub-agents)
# Jac:  `task = flow root spawn HWResearcher(topic=self.topic)`
#       `result = wait task`  — clean async-safe future
# Here: you manage ThreadPoolExecutor, capture futures, re-raise exceptions,
#       and coordinate the collect step manually.
# ===========================================================================

def run_researcher(role_prompt: str, topic: str) -> str:
    """A researcher sub-agent: uses tools to investigate a topic."""
    # Without Jac's typed walker + sem, the user_prompt must also be explicit
    # about what the researcher is expected to produce and return.
    return llm_with_tools(
        system_prompt=role_prompt,
        user_prompt=(
            f"Investigate the following research topic from your area of expertise. "
            f"Your findings will be handed off to a synthesis agent that will combine "
            f"them with findings from other specialist researchers into a unified survey, "
            f"so write for an audience of peer researchers, not a general audience.\n\n"
            f"Research topic: {topic}\n\n"
            f"Investigation process you MUST follow:\n"
            f"  Step 1 — Search broadly: call search_papers with a general query "
            f"           that captures the main concepts of the topic.\n"
            f"  Step 2 — Search narrowly: call search_papers again with a more "
            f"           targeted query focused on your area of specialization.\n"
            f"  Step 3 — Assess impact: call get_citations on the 2 papers that "
            f"           appear most central or foundational to the topic.\n"
            f"  Step 4 — Synthesize: write your final summary using only what you "
            f"           found in steps 1-3. Do not rely on your training-data knowledge "
            f"           alone — ground your answer in the retrieved papers.\n\n"
            f"Your final response must be structured prose covering:\n"
            f"  a) The core technical problem and why it matters in this topic area\n"
            f"  b) The most important papers and their contributions\n"
            f"  c) Citation impact of the key papers (use actual numbers from get_citations)\n"
            f"  d) Current state-of-the-art approaches from your track's perspective\n"
            f"  e) Remaining open challenges that future research should address\n\n"
            f"Format constraints:\n"
            f"  - Prose paragraphs only (no bullets, no numbered lists, no headers)\n"
            f"  - Do not include JSON, tool call names, or metadata in your response\n"
            f"  - Do not add a title or preamble — start directly with the content"
        ),
    )


# In Jac these are one-line `sem` annotations; the framework constructs
# the full system prompt automatically from the signature + sem + tool list.
# Without that, you must write the entire instruction set by hand.
# In Jac these are one-line `sem` annotations; the framework constructs
# the full system prompt automatically from the method signature + sem + tool list.
# Without that, you must write the entire role definition, scope, process, and
# output contract by hand — for every researcher variant separately.
RESEARCHER_PROMPTS = {
    "hardware": (
        "You are a senior hardware architecture researcher with deep expertise in "
        "computer systems design for machine learning workloads. Your specialization "
        "covers the following areas:\n"
        "  - Processor microarchitecture: pipelines, out-of-order execution, SIMD\n"
        "  - Memory hierarchy: L1/L2/L3 caches, TLBs, cache coherence protocols\n"
        "  - Off-chip memory: DRAM, HBM2/3, bandwidth and latency tradeoffs\n"
        "  - AI accelerators: Google TPUs, NVIDIA GPUs, custom NPUs, FPGAs\n"
        "  - Processing-in-memory (PIM) and near-data computing architectures\n"
        "  - Interconnects: NVLink, PCIe, CXL for multi-chip AI systems\n\n"
        "Your goal is to investigate a research topic and produce a concise but "
        "technically rigorous summary from a hardware architecture perspective. "
        "You have access to two tools:\n"
        "  - search_papers(query): searches arXiv for academic papers\n"
        "  - get_citations(paper_title): retrieves citation count from OpenAlex\n\n"
        "Tool usage policy:\n"
        "  1. Call search_papers at least twice with different focused queries "
        "     to maximize coverage (e.g., one broad query, one narrow).\n"
        "  2. Review all returned titles and abstracts before deciding relevance.\n"
        "  3. Call get_citations on the 2 most impactful papers to gauge their "
        "     influence in the research community.\n"
        "  4. Do not fabricate paper titles or citation numbers.\n\n"
        "Output requirements:\n"
        "  - Write 4-6 paragraphs of formal technical prose.\n"
        "  - Cover: key hardware bottlenecks, notable architectural solutions, "
        "    highly-cited works, and remaining open problems.\n"
        "  - Do NOT use bullet points or numbered lists in the final summary.\n"
        "  - Do NOT return JSON or structured data.\n"
        "  - Do NOT start with 'As a hardware researcher...' or similar preamble."
    ),
    "systems": (
        "You are a senior systems software researcher with deep expertise in "
        "system-level support for machine learning workloads. Your specialization "
        "covers the following areas:\n"
        "  - Compiler optimizations for ML: operator fusion, tiling, vectorization\n"
        "  - ML compilation frameworks: TVM, XLA, MLIR, Triton\n"
        "  - Runtime systems: CUDA runtime, ROCm, execution engines\n"
        "  - Operating system support: memory management, I/O scheduling, NUMA\n"
        "  - Distributed training infrastructure: collective communication, AllReduce\n"
        "  - Inference serving systems: batching, KV-cache management, scheduling\n\n"
        "Your goal is to investigate a research topic and produce a concise but "
        "technically rigorous summary from a systems software perspective. "
        "You have access to two tools:\n"
        "  - search_papers(query): searches arXiv for academic papers\n"
        "  - get_citations(paper_title): retrieves citation count from OpenAlex\n\n"
        "Tool usage policy:\n"
        "  1. Call search_papers at least twice with different focused queries "
        "     to maximize coverage (e.g., one systems-focused, one compiler-focused).\n"
        "  2. Review all returned titles and abstracts before deciding relevance.\n"
        "  3. Call get_citations on the 2 most impactful papers to gauge their "
        "     influence in the research community.\n"
        "  4. Do not fabricate paper titles or citation numbers.\n\n"
        "Output requirements:\n"
        "  - Write 4-6 paragraphs of formal technical prose.\n"
        "  - Cover: key systems bottlenecks, notable software solutions, "
        "    highly-cited works, and remaining open problems.\n"
        "  - Do NOT use bullet points or numbered lists in the final summary.\n"
        "  - Do NOT return JSON or structured data.\n"
        "  - Do NOT start with 'As a systems researcher...' or similar preamble."
    ),
    "ml": (
        "You are a senior machine learning researcher with deep expertise in "
        "efficient neural network design and optimization. Your specialization "
        "covers the following areas:\n"
        "  - Model architecture: Transformers, attention variants (FlashAttention, "
        "    grouped-query attention), mixture-of-experts (MoE)\n"
        "  - Training efficiency: mixed-precision training, gradient checkpointing, "
        "    ZeRO optimizer, data parallelism and model parallelism\n"
        "  - Inference optimization: quantization (INT8/INT4/FP8), pruning, "
        "    structured sparsity, knowledge distillation, speculative decoding\n"
        "  - Large language models: GPT, LLaMA, Mistral, and efficient LLM variants\n"
        "  - Evaluation: perplexity, latency, throughput, accuracy-efficiency tradeoffs\n\n"
        "Your goal is to investigate a research topic and produce a concise but "
        "technically rigorous summary from an ML algorithms perspective. "
        "You have access to two tools:\n"
        "  - search_papers(query): searches arXiv for academic papers\n"
        "  - get_citations(paper_title): retrieves citation count from OpenAlex\n\n"
        "Tool usage policy:\n"
        "  1. Call search_papers at least twice with different focused queries "
        "     to maximize coverage (e.g., one on model architecture, one on inference).\n"
        "  2. Review all returned titles and abstracts before deciding relevance.\n"
        "  3. Call get_citations on the 2 most impactful papers to gauge their "
        "     influence in the research community.\n"
        "  4. Do not fabricate paper titles or citation numbers.\n\n"
        "Output requirements:\n"
        "  - Write 4-6 paragraphs of formal technical prose.\n"
        "  - Cover: key algorithmic innovations, notable model designs, "
        "    highly-cited works, and remaining open problems.\n"
        "  - Do NOT use bullet points or numbered lists in the final summary.\n"
        "  - Do NOT return JSON or structured data.\n"
        "  - Do NOT start with 'As an ML researcher...' or similar preamble."
    ),
}


def spawn_researchers(selected_tracks: list[str], topic: str) -> list[str]:
    """Spawn one researcher thread per selected track; wait for all to finish."""
    findings = []
    # ThreadPoolExecutor is the manual equivalent of `flow spawn` + `wait`
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(selected_tracks)) as executor:
        future_to_track = {
            executor.submit(
                run_researcher,
                RESEARCHER_PROMPTS[track],
                topic,
            ): track
            for track in selected_tracks
        }

        for future in concurrent.futures.as_completed(future_to_track):
            track = future_to_track[future]
            try:
                result = future.result()
                findings.append(result)
                print(f"  Researcher done ({track}).")
            except Exception as exc:
                # Jac surfaces this automatically; here we handle it manually
                print(f"  Researcher {track} raised: {exc}")
                findings.append(f"[Research failed for {track}: {exc}]")

    return findings


# ===========================================================================
# Primitive 6 — PIPE (sequential data flow)
# Jac:  graph edges encode the flow; the walker moves forward automatically
# Here: explicit function calls in sequence — the "pipe" is just your call stack
# ===========================================================================

def write_survey(topic: str, findings: list[str]) -> str:
    findings_text = "\n\n---\n\n".join(findings)
    # Without Jac's `sem` annotation on write_survey, you must fully specify
    # the expected output structure, audience, length, and tone.
    return llm_generate(
        system_prompt=(
            "You are a lead author writing a technical survey paper for presentation "
            "at a top-tier computer architecture conference tutorial (e.g., ASPLOS, "
            "ISCA, MICRO, HPCA). Your audience consists of PhD students and researchers "
            "who are knowledgeable about computer systems in general but may not be "
            "specialists in every sub-field you cover. Your writing must be precise, "
            "well-structured, and synthesize ideas across hardware, systems, and ML "
            "perspectives into a unified narrative. Avoid excessive jargon without "
            "definition, and do not simply list findings — weave them into a story."
        ),
        user_prompt=(
            f"Write a comprehensive unified technical survey on the following topic:\n"
            f"  Topic: {topic}\n\n"
            f"You have received research reports from multiple domain-specialist agents "
            f"(hardware, systems software, and ML). Your job is to synthesize their "
            f"findings into a single cohesive survey — not a concatenation.\n\n"
            f"Required structure (use these exact section headings):\n\n"
            f"  ## Abstract\n"
            f"  3-5 sentences. State the topic, the sub-fields covered, key themes, "
            f"  and the survey's intended audience.\n\n"
            f"  ## 1. Introduction\n"
            f"  Motivate the topic: why is it important now? What gap in the literature "
            f"  or industry need does it address? State the scope and organization.\n\n"
            f"  ## 2. Background\n"
            f"  Define key terms and concepts that a reader needs to follow the rest "
            f"  of the survey. Cover hardware, systems, and ML foundations briefly.\n\n"
            f"  ## 3. Research Landscape\n"
            f"  Integrate findings from all specialist tracks. Do NOT organize this "
            f"  section by track (not 'Hardware findings', 'Systems findings', etc.) — "
            f"  instead organize by theme or problem dimension, weaving perspectives "
            f"  together. Cross-reference findings where they are complementary or "
            f"  conflicting.\n\n"
            f"  ## 4. Open Challenges\n"
            f"  Identify 3-5 concrete open research problems that span multiple tracks. "
            f"  Each challenge should explain why it is hard and what a solution would "
            f"  require from hardware, systems, and/or ML perspectives.\n\n"
            f"  ## 5. Conclusion\n"
            f"  Summarize the key takeaways and the outlook for the field.\n\n"
            f"Specialist research findings:\n\n{findings_text}\n\n"
            f"Writing requirements:\n"
            f"  - Target length: 700-1000 words (excluding headings).\n"
            f"  - Do NOT copy sentences from the findings verbatim — paraphrase and "
            f"    synthesize.\n"
            f"  - Use formal academic prose throughout.\n"
            f"  - Cross-reference findings across tracks (e.g., 'the compiler "
            f"    optimizations described above are enabled by the memory hierarchies...').\n"
            f"  - Do not include a References section; cite paper titles inline if needed.\n"
            f"  - Do not add author names, affiliations, or a date."
        ),
    )


def revise_survey(survey: str, feedback: str) -> str:
    # Without Jac's sem annotation, you must explicitly tell the model:
    # what to keep, what to change, and what the output must look like.
    return llm_generate(
        system_prompt=(
            "You are a lead author revising a technical survey in response to "
            "peer-review feedback from a top-tier computer architecture conference. "
            "Your revision must be thorough and targeted: address every identified gap "
            "and incorporate every suggestion, but do not introduce new factual claims "
            "that go beyond what was established in the original research findings. "
            "Preserve the structure, voice, and valid content of the original survey; "
            "only change what the reviewer asked you to change. The output must be a "
            "complete, self-contained revised survey — not a diff or patch."
        ),
        user_prompt=(
            f"Revise the technical survey below based on the peer-reviewer's feedback.\n\n"
            f"=== ORIGINAL SURVEY ===\n{survey}\n\n"
            f"=== REVIEWER FEEDBACK ===\n{feedback}\n\n"
            f"Revision checklist — you MUST address each item:\n"
            f"  1. Coverage gaps: for every gap listed by the reviewer, add or expand "
            f"     content in the most appropriate section. If a topic is not in the "
            f"     specialist findings but is flagged as missing, acknowledge it as "
            f"     future work in Section 4 (Open Challenges).\n"
            f"  2. Suggestions: implement each actionable suggestion. If a suggestion "
            f"     conflicts with another, use your judgment and note the trade-off "
            f"     inline (briefly).\n"
            f"  3. Unchanged sections: do not alter sections or paragraphs that were "
            f"     not mentioned in the feedback.\n"
            f"  4. Structure preservation: the revised survey must use the same "
            f"     section headings (Abstract, Introduction, Background, Research "
            f"     Landscape, Open Challenges, Conclusion).\n"
            f"  5. Length: the revised survey should be at least as long as the "
            f"     original and may be longer if additional content is warranted.\n\n"
            f"Output format:\n"
            f"  - Return the COMPLETE revised survey from Abstract to Conclusion.\n"
            f"  - Do NOT include a summary of changes, revision notes, or a diff.\n"
            f"  - Do NOT include phrases like 'In response to the reviewer...'.\n"
            f"  - Start directly with '## Abstract'."
        ),
    )


# ===========================================================================
# Primitive 7 — LOOP (self-critique cycle)
# Jac:  `while revision < self.max_revisions { ... }` with Extract inside
# Here: same while loop but you manually call llm_extract_review, parse the
#       verdict enum, and format the feedback string each iteration.
# ===========================================================================

def review_and_revise(topic: str, survey: str, max_revisions: int = 2) -> str:
    revision = 0
    while revision < max_revisions:
        revision += 1
        print(f"\n  [Review Round {revision}]")

        # Without Jac's typed return `-> SurveyReview by llm()`, you must also
        # spell out the evaluation criteria so the model fills the schema correctly.
        review = llm_extract_review(
            system_prompt=(
                "You are a rigorous peer reviewer for a top-tier computer architecture "
                "conference (ASPLOS, ISCA, MICRO, or HPCA). You are evaluating a "
                "technical survey intended for a tutorial session. Your evaluation will "
                "be used directly to drive automated revisions, so your feedback must "
                "be specific, actionable, and grounded in the survey's actual content — "
                "not vague or generic. Avoid praise; focus on what is missing or weak. "
                "Apply the bar of a strong accept only to surveys that are genuinely "
                "complete, well-written, and cross-disciplinary in their coverage. "
                "If any dimension is weak, use NEEDS_REVISION."
            ),
            user_prompt=(
                f"Critically evaluate the following technical survey.\n\n"
                f"Topic the survey should cover: '{topic}'\n\n"
                f"=== SURVEY TEXT ===\n{survey}\n\n"
                f"=== END OF SURVEY ===\n\n"
                f"Evaluate the survey on each of the following dimensions. For each "
                f"weakness, you will record it as a coverage gap or suggestion.\n\n"
                f"Evaluation dimensions:\n"
                f"  1. Cross-disciplinary coverage — Does the survey integrate hardware, "
                f"     systems software, AND ML algorithm perspectives? A survey that "
                f"     only covers one or two tracks is incomplete.\n"
                f"  2. Technical depth — Are key papers, techniques, and results cited "
                f"     with sufficient specificity? Vague claims like 'researchers have "
                f"     shown improvements' are insufficient.\n"
                f"  3. Synthesis quality — Are findings from different tracks connected "
                f"     and cross-referenced, or merely listed side-by-side?\n"
                f"  4. Open challenges — Does Section 4 identify concrete, multi-track "
                f"     research problems? Generic statements do not qualify.\n"
                f"  5. Audience accessibility — Can a PhD student in systems (but not "
                f"     ML) follow the survey? Is background adequately explained?\n"
                f"  6. Structure and completeness — Are all required sections present "
                f"     (Abstract, Intro, Background, Research Landscape, Open Challenges, "
                f"     Conclusion)? Are any sections disproportionately short?\n\n"
                f"Output schema instructions:\n"
                f"  verdict:\n"
                f"    Use 'PUBLISH_READY' ONLY if the survey passes all 6 dimensions "
                f"    above with no meaningful weaknesses. Otherwise use 'NEEDS_REVISION'.\n\n"
                f"  coverage_gaps:\n"
                f"    A list of strings, each naming a specific topic, sub-field, or "
                f"    perspective that is missing or under-represented. Be precise: "
                f"    write 'No discussion of KV-cache memory management for LLM serving' "
                f"    not 'more systems content needed'. Empty list only if verdict is "
                f"    PUBLISH_READY.\n\n"
                f"  suggestions:\n"
                f"    A list of strings, each a concrete, actionable revision instruction. "
                f"    Good example: 'Add a paragraph to Section 3 comparing TPU and GPU "
                f"    memory bandwidth and how this affects attention computation.' "
                f"    Bad example: 'Improve the hardware section.' Empty list only if "
                f"    verdict is PUBLISH_READY."
            ),
        )

        print(f"  Verdict: {review['verdict'].value}")
        print(f"  Gaps: {review['coverage_gaps']}")

        if review["verdict"] == Verdict.PUBLISH_READY:
            print("  Survey approved!")
            break

        feedback = (
            f"Gaps: {review['coverage_gaps']}. "
            f"Suggestions: {review['suggestions']}"
        )
        survey = revise_survey(survey, feedback)
        print(f"  Revised (v{revision + 1})")

    return survey


# ===========================================================================
# Main — ties the pipeline together (what the walker graph topology does in Jac)
# ===========================================================================

def run_survey_agent(topic: str, max_revisions: int = 2) -> str:
    print(f"=== Survey Agent: {topic} ===\n")

    # Phase 1 — Route
    print("[Phase 1] Routing to relevant tracks...\n")
    selected_tracks = route_tracks(topic)
    for t in selected_tracks:
        print(f"  [Route → {t.title()}] Selected by LLM")

    # Phase 2 — Spawn (parallel researchers) + Invoke (tool calls inside each)
    print("\n[Phase 2] Waiting for researchers...")
    findings = spawn_researchers(selected_tracks, topic)

    # Phase 3 — Pipe + Generate (synthesize)
    print("\n[Phase 3] Synthesizing survey...")
    survey = write_survey(topic, findings)

    # Phase 4 — Loop + Extract (review-revise cycle)
    print("\n[Phase 4] Review cycle...")
    survey = review_and_revise(topic, survey, max_revisions)

    return survey


if __name__ == "__main__":
    final_survey = run_survey_agent(
        topic="Hardware-software co-design for efficient LLM inference",
        max_revisions=2,
    )

    print(f"\n{'=' * 60}")
    print("FINAL SURVEY")
    print(f"{'=' * 60}")
    print(final_survey)
