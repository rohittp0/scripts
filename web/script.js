let scriptsData = [];

document.addEventListener("DOMContentLoaded", () => {
  const pemPathInput = document.getElementById("pemPath");
  const sshUserInput = document.getElementById("sshUser");
  const hostInput = document.getElementById("host");
  const portInput = document.getElementById("port");

  const scriptSelect = document.getElementById("scriptSelect");
  const paramsTable = document.getElementById("paramsTable");
  const paramsTableBody = paramsTable.querySelector("tbody");
  const sshCommandOutput = document.getElementById("sshCommandOutput");
  const scriptDescription = document.getElementById("scriptDescription");

  // Fetch JSON data
  fetch("./index.json")
    .then((response) => response.json())
    .then((data) => {
      scriptsData = data;
      populateScripts();
      renderParams(); // Render initial selection
      buildSSHCommand(); // Build initial command
    })
    .catch((error) => {
      console.error("Error fetching index.json:", error);
    });

  // Populate script dropdown with fetched data
  function populateScripts() {
    // Clear any existing options
    scriptSelect.innerHTML = "";

    // Add a default "Select a script" option
    const defaultOption = document.createElement("option");
    defaultOption.value = "";
    defaultOption.textContent = "-- Select a script --";
    scriptSelect.appendChild(defaultOption);

    // Add scripts from JSON
    scriptsData.forEach((script, index) => {
      const option = document.createElement("option");
      option.value = index;
      option.textContent = script.name;
      scriptSelect.appendChild(option);
    });
  }

  // Build the SSH command string (using curl)
  function buildSSHCommand() {
    const pemPath = pemPathInput.value.trim() || "~/.ssh/";
    const sshUser = sshUserInput.value.trim() || "root";
    const host = hostInput.value.trim() || "example.com";
    const port = parseInt(portInput.value.trim(), 10) || 22;

    const selectedScriptIndex = scriptSelect.value;
    // If no valid script is selected
    if (selectedScriptIndex === "") {
      sshCommandOutput.textContent = "Please select a script.";
      return;
    }
    const selectedScript = scriptsData[selectedScriptIndex];

    // Collect parameter values from table
    const paramInputs = paramsTableBody.querySelectorAll("input");
    const params = [];
    paramInputs.forEach((input) => {
      params.push(input.value.trim());
    });

    // Base SSH command
    let command = "ssh ";

    // If port is not 22, add -p flag
    if (port !== 22) {
      command += `-p ${port} `;
    }

    command += `-i ${pemPath} ${sshUser}@${host} `;

    // Use curl to fetch the script by URL/path, then pipe to bash
    // The script may need quotes if it has spaces, etc., but for demonstration:
    command += `"curl -sS ${location.href}${selectedScript.path} | bash -s`;

    // If params exist, append them
    if (params.length) {
      command += " " + params.join(" ");
    }

    command += `"`;

    // Update output
    sshCommandOutput.textContent = command;
  }

  // Render parameters for the selected script + description
  function renderParams() {
    // Clear existing params
    paramsTableBody.innerHTML = "";

    const selectedScriptIndex = scriptSelect.value;
    // If no script is selected, hide table and clear description
    if (selectedScriptIndex === "") {
      paramsTable.classList.add("hidden");
      scriptDescription.textContent = "";
      return;
    }

    const selectedScript = scriptsData[selectedScriptIndex];
    const scriptParams = selectedScript.params || [];

    // Update script description
    scriptDescription.textContent = selectedScript.desc || "No description available.";

    if (scriptParams.length === 0) {
      // No params
      paramsTable.classList.add("hidden");
    } else {
      paramsTable.classList.remove("hidden");
      scriptParams.forEach((param) => {
        const row = document.createElement("tr");
        const paramCell = document.createElement("td");
        const inputCell = document.createElement("td");
        const input = document.createElement("input");

        paramCell.textContent = param;
        input.type = "text";
        input.placeholder = param;
        // Whenever param value changes, rebuild command
        input.addEventListener("input", buildSSHCommand);

        inputCell.appendChild(input);
        row.appendChild(paramCell);
        row.appendChild(inputCell);
        paramsTableBody.appendChild(row);
      });
    }

    // Update the command after rendering
    buildSSHCommand();
  }

  // Copy to clipboard functionality
  const copyButton = document.getElementById("copyButton");
  
  copyButton.addEventListener("click", () => {
    const command = sshCommandOutput.textContent;
    
    // Create a temporary textarea element to hold the command
    const textarea = document.createElement("textarea");
    textarea.value = command;
    document.body.appendChild(textarea);
    textarea.select();
    
    try {
      // Execute the copy command
      document.execCommand("copy");
      
      // Change the button text temporarily
      const originalText = copyButton.textContent;
      copyButton.textContent = "Copied!";
      
      // Reset the text after 2 seconds
      setTimeout(() => {
        copyButton.textContent = originalText;
      }, 2000);
      
    } catch (err) {
      console.error("Failed to copy command: ", err);
    } finally {
      // Clean up
      document.body.removeChild(textarea);
    }
  });

  // Event listeners
  scriptSelect.addEventListener("change", () => {
    renderParams();
  });

  pemPathInput.addEventListener("input", buildSSHCommand);
  sshUserInput.addEventListener("input", buildSSHCommand);
  hostInput.addEventListener("input", buildSSHCommand);
  portInput.addEventListener("input", buildSSHCommand);
});