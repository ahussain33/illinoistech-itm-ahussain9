from docx import Document
import PyPDF2


def _extract_text_from_pdf(file_path: str) -> str:
    text_chunks = []
    with open(file_path, "rb") as f:
        reader = PyPDF2.PdfReader(f)
        for page in reader.pages:
            page_text = page.extract_text()
            if page_text:
                text_chunks.append(page_text)
    return "\n".join(text_chunks)


def _extract_text_from_docx(file_path: str) -> str:
    """Extract text from a DOCX file."""
    doc = Document(file_path)
    return "\n".join(p.text for p in doc.paragraphs if p.text.strip())


def parse_resume(file_path: str) -> dict:
   
    data = {
        "personal": {},
        "education": [],
        "experience": [],
        "skills": [],
        "projects": [],
        "raw_text": "",  
    }

    # 1. Extract raw text
    if file_path.lower().endswith(".pdf"):
        text = _extract_text_from_pdf(file_path)
    else:
        # Treat as DOCX by default
        text = _extract_text_from_docx(file_path)

    data["raw_text"] = text  # you can drop this if you don't want it in S3

    lines = [l.strip() for l in text.splitlines() if l.strip()]

    section = None

    for line in lines:
        upper_line = line.upper()

        # --- Detect section headers (Harvard template-ish) ---
        if "PERSONAL INFORMATION" in upper_line or "CONTACT" in upper_line:
            section = "personal"
            continue
        if upper_line.startswith("EDUCATION"):
            section = "education"
            continue
        if "WORK EXPERIENCE" in upper_line or upper_line.startswith("EXPERIENCE"):
            section = "experience"
            continue
        if upper_line.startswith("SKILLS"):
            section = "skills"
            continue
        if upper_line.startswith("PROJECTS"):
            section = "projects"
            continue

        # If we haven't hit a section yet, skip
        if section is None:
            continue

        # --- Parse content based on section ---
        if section == "personal":
            key_val = line.split(":", 1)
            if len(key_val) == 2:
                key = key_val[0].strip()
                value = key_val[1].strip()
                if key and value:
                    data["personal"][key] = value
        elif section in ("education", "experience", "skills", "projects"):
            if line:
                data[section].append(line)

    return data
