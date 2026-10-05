import asyncio
import sys
from pathlib import Path

import streamlit as st

ROOT = Path(__file__).resolve().parent
BACKEND = ROOT / "backend"
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

from app.agent.research import run_research
from app.models import ResearchRequest


st.set_page_config(page_title="LexSutra Research", page_icon="⚖️", layout="wide")


async def _run_research(question: str, keywords: str, jurisdiction: str):
    payload = ResearchRequest(
        question=question,
        keywords=keywords,
        jurisdiction=jurisdiction,
    )
    return await run_research(payload)


def main():
    st.title("LexSutra — Legal Research")
    st.caption("Streamlit deployment version for the Nepal legal research workspace")

    with st.form("research_form"):
        question = st.text_area(
            "Question or case facts *",
            placeholder="Describe the dispute, legal question, or facts you need to research...",
            height=140,
        )
        keywords = st.text_input(
            "Keywords (optional)",
            placeholder="e.g. land sale, contract breach",
        )
        jurisdiction = st.selectbox(
            "Jurisdiction",
            ["Nepal", "Supreme Court of Nepal", "Provincial / District courts"],
            index=0,
        )
        submitted = st.form_submit_button("Start research")

    if not submitted:
        st.info("Provide a legal question to begin research.")
        return

    if len(question.strip()) < 12:
        st.warning("Please enter a more specific question with at least 12 characters.")
        return

    with st.spinner("Running legal research..."):
        try:
            report = asyncio.run(_run_research(question, keywords, jurisdiction))
        except Exception as exc:  # pragma: no cover - UI fallback
            st.error(f"Research failed: {exc}")
            return

    st.success("Research completed")

    st.subheader("Findings")
    st.write(report.findings)

    if report.legal_principles:
        st.subheader("Legal principles")
        for item in report.legal_principles:
            st.markdown(f"- {item}")

    if report.provisions:
        st.subheader("Relevant provisions")
        for provision in report.provisions:
            with st.expander(f"{provision.law_name} — {provision.section}"):
                st.write(provision.explanation)
                st.caption(f"Source: {provision.source_id}")

    if report.cases:
        st.subheader("Similar judgments")
        for case in report.cases:
            with st.expander(f"{case.case_name} — {case.similarity:.0%} similarity"):
                st.write(case.summary)
                st.write(f"Court: {case.court}")
                if case.date:
                    st.write(f"Date: {case.date}")
                if case.case_number:
                    st.write(f"Case no.: {case.case_number}")
                if case.relevance:
                    st.write("Relevance:")
                    for reason in case.relevance:
                        st.write(f"- {reason}")

    if report.sources:
        st.subheader("Sources")
        for source in report.sources:
            st.markdown(f"- [{source.title}]({source.url}) — {source.source_name}")

    if report.limitations:
        st.subheader("Limitations")
        for item in report.limitations:
            st.warning(item)

    st.caption(report.disclaimer)


if __name__ == "__main__":
    main()
