document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("uploadForm");
  const fileInput = document.getElementById("resumeFile");
  const responsePre = document.getElementById("response");

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    responsePre.textContent = "Uploading...";

    const file = fileInput.files[0];
    if (!file) {
      responsePre.textContent = "Choose a file";
      return;
    }

    const formData = new FormData();
    formData.append("file", file);

    let res;
    try {
      res = await fetch("/upload", {
        method: "POST",
        body: formData,
      });
    } catch (err) {
      responsePre.textContent = "Network error: " + err.message;
      return;
    }

    let data;
    try {
      data = await res.json();
    } catch (err) {
      responsePre.textContent =
        `Error: server did not return JSON (status ${res.status}).\n\n` +
        `Raw response:\n${await res.text()}`;
      return;
    }

    if (!res.ok || data.status === "error") {
      responsePre.textContent =
        "Upload failed: " + (data.message || `status ${res.status}`);
      return;
    }

    let output = "";
    output += `Upload successful!\n`;
    output += `S3 key: ${data.s3_key}\n\n`;

    output += "Full Extracted Text\n";
    output += (data.parsed_text || "(No text extracted)") + "\n\n";

    if (data.parsed) {
      output += "Resume Data in Categories\n";

      if (data.parsed.personal && Object.keys(data.parsed.personal).length) {
        output += "\n[Personal]\n";
        for (const [key, val] of Object.entries(data.parsed.personal)) {
          output += `- ${key}: ${val}\n`;
        }
      }

      if (data.parsed.education?.length) {
        output += "\n[Education]\n";
        data.parsed.education.forEach((line) => {
          output += `- ${line}\n`;
        });
      }

      if (data.parsed.experience?.length) {
        output += "\n[Experience]\n";
        data.parsed.experience.forEach((line) => {
          output += `- ${line}\n`;
        });
      }

      if (data.parsed.skills?.length) {
        output += "\n[Skills]\n";
        data.parsed.skills.forEach((line) => {
          output += `- ${line}\n`;
        });
      }

      if (data.parsed.projects?.length) {
        output += "\n[Projects]\n";
        data.parsed.projects.forEach((line) => {
          output += `- ${line}\n`;
        });
      }
    }

    responsePre.textContent = output;
  });
});

