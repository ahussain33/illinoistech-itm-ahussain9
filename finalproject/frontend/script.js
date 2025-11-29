const form = document.getElementById("uploadForm");
const fileInput = document.getElementById("resumeFile");
const resultDiv = document.getElementById("result"); // a <div> to show messages

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  resultDiv.textContent = "";

  const file = fileInput.files[0];
  if (!file) {
    resultDiv.textContent = "Please choose a file before uploading.";
    return;
  }

  const formData = new FormData();
  formData.append("file", file);

  let response;
  try {
    response = await fetch("/upload", {
      method: "POST",
      body: formData,
    });
  } catch (err) {
    resultDiv.textContent = "Network error: " + err.message;
    return;
  }

  // Read the raw text first
  const text = await response.text();

  let data;
  try {
    data = JSON.parse(text);
  } catch (err) {
    // The server returned non-JSON (likely an HTML error page)
    resultDiv.textContent =
      `Error: server did not return JSON (status ${response.status}). ` +
      `Raw response:\n` +
      text;
    return;
  }

  // Now we have valid JSON
  if (!response.ok || data.status === "error") {
    resultDiv.textContent =
      "Upload failed: " + (data.message || `status ${response.status}`);
  } else {
    resultDiv.textContent =
      "Upload successful! Stored in S3 key: " + data.s3_key;
  }
});
