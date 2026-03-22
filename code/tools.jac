"""Shared research tools used across tutorial steps.
These are regular functions that the LLM can use via Invoke."""

import json;
import from urllib.request { urlopen, Request }
import from urllib.parse { quote }
import from xml.etree.ElementTree { fromstring }

def search_papers(query: str, max_results: int = 3) -> str {
    try {
        url = f"http://export.arxiv.org/api/query?search_query=all:{quote(
            query
        )}&max_results={max_results}";
        resp = urlopen(url, timeout=10).read().decode();
        xml_root = fromstring(resp);
        ns = {"atom": "http://www.w3.org/2005/Atom"};
        papers: list = [];
        for entry in xml_root.findall("atom:entry", ns) {
            title = entry.find("atom:title", ns).text.strip();
            abstract = entry.find("atom:summary", ns).text.strip();
            papers.append({"title": title, "abstract": abstract});
        }
        return json.dumps(papers, indent=2);
    } except Exception as e {
        return f"Search failed: {e}";
    }
}

def get_citations(paper_title: str) -> str {
    try {
        url = f"https://api.openalex.org/works?search={quote(
            paper_title
        )}&per_page=1&select=title,cited_by_count";
        req = Request(url, headers={"User-Agent": "JacTutorial/1.0"});
        resp = json.loads(urlopen(req, timeout=10).read().decode());
        if resp.get("results") and len(resp["results"]) > 0 {
            paper = resp["results"][0];
            return f"{paper['title']} has been cited {paper['cited_by_count']} times.";
        }
        return f"No citation data found for '{paper_title}'.";
    } except Exception as e {
        return f"Citation lookup failed: {e}";
    }
}

def summarize_abstract(abstract: str) -> str by llm();

sem search_papers = "Search for academic papers matching a query. Returns titles and abstracts.";
sem get_citations = "Get citation count for a paper by title.";
sem summarize_abstract = "Summarize a paper abstract in one sentence.";
