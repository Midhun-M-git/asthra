from __future__ import annotations

import json
import os
import textwrap
import zipfile
from pathlib import Path
from typing import Any, Dict, List, Tuple

from fastapi import FastAPI, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pptx import Presentation
from pptx.util import Pt
from reportlab.lib.pagesizes import LETTER
from reportlab.pdfgen import canvas

# Optional AI integration (OpenAI, Azure OpenAI, Gemini, Bedrock)
AI_ENABLED = False
AI_PROVIDER = os.getenv("AI_PROVIDER", "auto").lower()
AI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
AI_STATUS_MSG = "AI not initialized"

client = None
bedrock_client = None

try:
    from openai import AzureOpenAI, OpenAI
except ImportError:  # pragma: no cover - optional dependency
    AzureOpenAI = None
    OpenAI = None

try:
    import google.generativeai as genai
except ImportError:  # pragma: no cover - optional dependency
    genai = None

try:
    import boto3
except ImportError:  # pragma: no cover - optional dependency
    boto3 = None


def _init_ai_provider() -> None:
    """Initialize the chosen AI provider if credentials are available."""
    global AI_ENABLED, AI_STATUS_MSG, client, bedrock_client, AI_PROVIDER

    provider = AI_PROVIDER

    # Auto-detect priority: Azure → Gemini → Bedrock → OpenAI
    if provider == "auto":
        if os.getenv("AZURE_OPENAI_ENDPOINT") and os.getenv("AZURE_OPENAI_API_KEY"):
            provider = "azure"
        elif os.getenv("GEMINI_API_KEY"):
            provider = "gemini"
        elif os.getenv("AWS_ACCESS_KEY_ID") or os.getenv("AWS_SESSION_TOKEN"):
            provider = "bedrock"
        elif os.getenv("OPENAI_API_KEY"):
            provider = "openai"
        else:
            AI_STATUS_MSG = "No AI credentials found; running in static mode"
            return

        AI_PROVIDER = provider
    if provider == "openai":
        if not OpenAI:
            AI_STATUS_MSG = "openai package not installed"
            return
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            AI_STATUS_MSG = "OPENAI_API_KEY missing"
            return
        client = OpenAI(api_key=api_key)
        AI_ENABLED = True
        AI_STATUS_MSG = "OpenAI ready"
        return

    if provider == "azure":
        if not AzureOpenAI:
            AI_STATUS_MSG = "openai package (AzureOpenAI) not installed"
            return
        endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        key = os.getenv("AZURE_OPENAI_API_KEY")
        model = os.getenv("AZURE_OPENAI_DEPLOYMENT") or os.getenv("AZURE_OPENAI_MODEL")
        api_version = os.getenv("AZURE_OPENAI_API_VERSION", "2024-02-01")
        if not (endpoint and key and model):
            AI_STATUS_MSG = "Azure OpenAI env vars missing (endpoint/key/deployment)"
            return
        client = AzureOpenAI(
            azure_endpoint=endpoint,
            api_key=key,
            api_version=api_version,
        )
        # reuse AI_MODEL for downstream calls
        globals()["AI_MODEL"] = model
        AI_ENABLED = True
        AI_STATUS_MSG = "Azure OpenAI ready"
        return

    if provider == "gemini":
        if not genai:
            AI_STATUS_MSG = "google-generativeai not installed"
            return
        key = os.getenv("GEMINI_API_KEY")
        model = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
        if not key:
            AI_STATUS_MSG = "GEMINI_API_KEY missing"
            return
        genai.configure(api_key=key)
        globals()["AI_MODEL"] = model
        AI_ENABLED = True
        AI_STATUS_MSG = "Gemini ready"
        return

    if provider == "bedrock":
        if not boto3:
            AI_STATUS_MSG = "boto3 not installed for Bedrock"
            return
        model = os.getenv(
            "AWS_BEDROCK_MODEL", "anthropic.claude-3-haiku-20240307-v1:0"
        )
        try:
            bedrock_client = boto3.client("bedrock-runtime")
            globals()["AI_MODEL"] = model
            AI_ENABLED = True
            AI_STATUS_MSG = "AWS Bedrock ready"
        except Exception as exc:  # noqa: BLE001
            AI_STATUS_MSG = f"Bedrock init error: {exc}"
        return

    AI_STATUS_MSG = f"Unknown AI_PROVIDER '{provider}'"


_init_ai_provider()

app = FastAPI()

# Allow frontend to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = Path(__file__).resolve().parent
FILES_DIR = BASE_DIR / "generated_files"
FILES_DIR.mkdir(exist_ok=True)


def _fallback_plan(message: str, file: UploadFile | None = None) -> Dict[str, Any]:
    """Static content used when AI is disabled or errors out."""
    file_note = f"Uploaded file: {file.filename}" if file else "No upload provided."
    return {
        "title": "ASTHRA Project Documentation",
        "summary": f"Generated documentation for: {message}",
        "sections": [
            {
                "heading": "Overview",
                "bullets": [
                    "Project statement received and logged.",
                    "ASTHRA generated offline demo content.",
                    file_note,
                ],
            },
            {
                "heading": "Objectives",
                "bullets": [
                    "Demonstrate PDF, PPT, patent draft, and certificates.",
                    "Content is sample-only when AI is disabled.",
                ],
            },
            {
                "heading": "Next Steps",
                "bullets": [
                    "Enable AI (set OPENAI_API_KEY) for richer drafts.",
                    "Refine requirements and rerun generation.",
                ],
            },
        ],
        "claims": [
            "A system that generates multiple documentation artifacts from one input.",
            "Automated slide and patent-style drafting based on project descriptions.",
        ],
        "certificate_note": "Demo certificate generated in offline mode.",
    }


def _system_prompt() -> str:
    return (
        "You are an assistant that drafts professional documentation. "
        "Return a concise JSON object with: "
        "`title` (string), `summary` (2-3 sentence string), "
        "`sections` (list of {heading, bullets[]}), "
        "`claims` (patent-style bullet points), "
        "`certificate_note` (short phrase for certificates). "
        "Use bullet-ready text, no markdown. Respond with JSON only."
    )


def _call_ai_plan(message: str) -> Tuple[Dict[str, Any] | None, str | None]:
    """Call the configured AI provider to get a structured documentation plan."""
    if not AI_ENABLED:
        return None, AI_STATUS_MSG

    try:
        if AI_PROVIDER in {"openai", "azure"} and client:
            response = client.chat.completions.create(
                model=AI_MODEL,
                temperature=0.4,
                max_tokens=1200,
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": _system_prompt()},
                    {"role": "user", "content": message},
                ],
            )
            raw_content = response.choices[0].message.content
            return json.loads(raw_content), None

        if AI_PROVIDER == "gemini":
            model = genai.GenerativeModel(AI_MODEL)
            response = model.generate_content(
                f"{_system_prompt()}\nUser request:\n{message}\nReply with JSON only."
            )
            raw_content = response.text
            return json.loads(raw_content), None

        if AI_PROVIDER == "bedrock" and bedrock_client:
            prompt = {
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": f"{_system_prompt()}\nUser request:\n{message}",
                            }
                        ],
                    }
                ],
                "max_tokens": 1200,
                "temperature": 0.4,
                "anthropic_version": "bedrock-2023-05-31",
            }
            result = bedrock_client.invoke_model(
                modelId=AI_MODEL, body=json.dumps(prompt)
            )
            payload = json.loads(result["body"].read())
            # Assume model returns JSON text in first message content
            raw_content = payload["content"][0]["text"]
            return json.loads(raw_content), None

        return None, f"Unsupported provider or client not initialized: {AI_PROVIDER}"
    except Exception as exc:  # noqa: BLE001
        return None, str(exc)


def _normalize_plan(plan: Dict[str, Any], fallback_message: str) -> Dict[str, Any]:
    """Ensure required fields exist and are in the expected format."""
    title = plan.get("title") or "ASTHRA Project Documentation"
    summary = plan.get("summary") or f"Generated documentation for: {fallback_message}"
    sections = []
    for section in plan.get("sections", []):
        heading = section.get("heading") or "Section"
        bullets = [b.strip() for b in section.get("bullets", []) if str(b).strip()]
        sections.append({"heading": heading, "bullets": bullets or ["Details pending."]})

    if not sections:
        sections = [
            {"heading": "Overview", "bullets": [summary]},
        ]

    claims = [
        c.strip() for c in plan.get("claims", []) if str(c).strip()
    ] or ["Automated documentation generation based on user input."]

    certificate_note = plan.get("certificate_note") or "Generated via ASTHRA."

    return {
        "title": title,
        "summary": summary,
        "sections": sections,
        "claims": claims,
        "certificate_note": certificate_note,
    }


def _wrap_lines(text: str, width: int) -> List[str]:
    return textwrap.wrap(text, width=width) if text else []


def _draw_header(c: canvas.Canvas, title: str) -> float:
    c.setFont("Helvetica-Bold", 20)
    c.drawString(60, 770, title)
    c.setFont("Helvetica", 11)
    return 740


def _draw_paragraph(c: canvas.Canvas, text: str, y: float, width: int = 90) -> float:
    for line in _wrap_lines(text, width):
        c.drawString(60, y, line)
        y -= 16
    return y


def _draw_sections(c: canvas.Canvas, sections: List[Dict[str, Any]], start_y: float) -> None:
    y = start_y
    for section in sections:
        heading = section["heading"]
        bullets = section["bullets"]

        if y < 120:
            c.showPage()
            y = _draw_header(c, "ASTHRA Report (cont.)")

        c.setFont("Helvetica-Bold", 13)
        c.drawString(60, y, heading)
        y -= 18

        c.setFont("Helvetica", 11)
        for bullet in bullets:
            for line in _wrap_lines(f"• {bullet}", 90):
                c.drawString(70, y, line)
                y -= 14
        y -= 6


def _build_report_pdf(plan: Dict[str, Any], path: Path) -> None:
    c = canvas.Canvas(str(path), pagesize=LETTER)
    y = _draw_header(c, plan["title"])
    c.setFont("Helvetica", 11)
    y = _draw_paragraph(c, plan["summary"], y)
    _draw_sections(c, plan["sections"], y - 4)
    c.save()


def _build_patent_pdf(plan: Dict[str, Any], message: str, path: Path) -> None:
    c = canvas.Canvas(str(path), pagesize=LETTER)
    y = _draw_header(c, "ASTHRA Patent Draft")
    c.setFont("Helvetica", 11)
    y = _draw_paragraph(c, f"Based on: {message}", y)

    c.setFont("Helvetica-Bold", 13)
    c.drawString(60, y, "Claims")
    y -= 18
    c.setFont("Helvetica", 11)
    for idx, claim in enumerate(plan["claims"], start=1):
        for line in _wrap_lines(f"{idx}. {claim}", 90):
            c.drawString(70, y, line)
            y -= 14

    c.save()


def _build_certificates_zip(plan: Dict[str, Any], message: str, path: Path) -> None:
    with zipfile.ZipFile(path, "w") as zipf:
        for i in range(1, 4):
            cert_pdf = FILES_DIR / f"certificate_{i}.pdf"
            c = canvas.Canvas(str(cert_pdf), pagesize=LETTER)
            c.setFont("Helvetica-Bold", 20)
            c.drawString(120, 720, f"Certificate #{i}")
            c.setFont("Helvetica", 12)
            c.drawString(120, 690, f"For project: {message}")
            c.drawString(120, 670, plan["certificate_note"])
            c.save()
            zipf.write(cert_pdf, cert_pdf.name)


def _build_ppt(plan: Dict[str, Any], path: Path) -> None:
    prs = Presentation()

    # Title slide
    title_slide = prs.slide_layouts[0]
    slide = prs.slides.add_slide(title_slide)
    slide.shapes.title.text = plan["title"]
    subtitle = slide.placeholders[1]
    subtitle.text = plan["summary"]
    subtitle.text_frame.paragraphs[0].font.size = Pt(18)

    # Section slides
    bullet_layout = prs.slide_layouts[1]
    for section in plan["sections"]:
        slide = prs.slides.add_slide(bullet_layout)
        slide.shapes.title.text = section["heading"]
        tf = slide.shapes.placeholders[1].text_frame
        tf.clear()
        for bullet in section["bullets"]:
            p = tf.add_paragraph()
            p.text = bullet
            p.level = 0

    # Claims slide
    slide = prs.slides.add_slide(bullet_layout)
    slide.shapes.title.text = "Patent-style Claims"
    tf = slide.shapes.placeholders[1].text_frame
    tf.clear()
    for claim in plan["claims"]:
        p = tf.add_paragraph()
        p.text = claim
        p.level = 0

    prs.save(str(path))


def _file_urls() -> Dict[str, str]:
    return {
        "report": "http://localhost:8000/files/report.pdf",
        "ppt": "http://localhost:8000/files/slides.pptx",
        "patent": "http://localhost:8000/files/patent.pdf",
        "certificates": "http://localhost:8000/files/certificates.zip",
    }


@app.post("/chat")
async def chat(
    message: str = Form(...),
    file: UploadFile | None = None,
    mode: str = Form("static"),
):
    """
    mode = "static" → generate demo files with fixed text
    mode = "hybrid" → enrich files with AI-generated content if API key is set
    """

    ai_error: str | None = None
    ai_used = False

    plan = _fallback_plan(message, file)
    if mode == "hybrid":
        ai_plan, ai_error = _call_ai_plan(message)
        if ai_plan:
            plan = _normalize_plan(ai_plan, message)
            ai_used = True

    report_path = FILES_DIR / "report.pdf"
    ppt_path = FILES_DIR / "slides.pptx"
    patent_path = FILES_DIR / "patent.pdf"
    cert_zip_path = FILES_DIR / "certificates.zip"

    _build_report_pdf(plan, report_path)
    _build_ppt(plan, ppt_path)
    _build_patent_pdf(plan, message, patent_path)
    _build_certificates_zip(plan, message, cert_zip_path)

    reply_lines = [plan["summary"]]
    if ai_error and not ai_used:
        reply_lines.append(f"AI fallback reason: {ai_error}")
    elif ai_error:
        reply_lines.append(f"AI warning: {ai_error}")

    return JSONResponse(
        {
            "reply": "\n".join(reply_lines),
            "files": _file_urls(),
            "ai": {
                "enabled": AI_ENABLED,
                "provider": AI_PROVIDER,
                "model": AI_MODEL,
                "status": AI_STATUS_MSG,
                "mode_requested": mode,
                "mode_used": "hybrid" if ai_used else "static",
                "error": ai_error,
            },
        }
    )


@app.get("/files/{filename}")
async def get_file(filename: str):
    file_path = FILES_DIR / filename
    if file_path.exists():
        return FileResponse(file_path)
    return JSONResponse({"error": "File not found"}, status_code=404)


@app.get("/status")
async def status():
    msg = AI_STATUS_MSG if AI_STATUS_MSG else "AI ready" if AI_ENABLED else "AI disabled"
    return {
        "ai_enabled": AI_ENABLED,
        "provider": AI_PROVIDER,
        "model": AI_MODEL,
        "message": msg,
    }

