# Scripts ✨

Welcome to **Scripts**, a project that allows you to **generate SSH commands** from a friendly **web UI**!  
Manage your servers, run handy scripts remotely, and streamline your dev operations – all from one place.

---

## 🚀 How It Works

1. **Web UI**  
   - Open the web interface (e.g., `index.html`) where you can fill in your SSH details:
     - **PEM File Path** (Default: `~/.ssh/`)
     - **SSH User** (Default: `root`)
     - **IP/Domain** (e.g., `example.com`)
     - **Port** (Default: `22`)  

2. **Select a Script**  
   - Choose from the scripts listed in `index.json`.  
   - If a script has parameters, you can fill those in.  

3. **Get Your Command**  
   - The UI automatically generates the **SSH command** you need.  
   - Simply copy and run it in your terminal to execute the script on the remote server.

---

## 🤝 Contributing

We love contributions! Here’s how you can add or update scripts:

1. **Fork** this repository.  
2. **Create a new script** in the `scripts/` folder (e.g., `scripts/mynewscript.sh`).  
3. **Update `index.json`** at the repository root:
   ```json
   [
     {
       "name": "My New Script",
       "path": "scripts/mynewscript.sh",
       "params": ["arg1", "arg2"],
       "desc": "Brief description of what this script does."
     }
   ]
   
# Available Scripts

Below are the scripts found in `index.json`:

## User Setup
- **Path**: `scripts/user.sh`
- **Description**: Creates a new 'ubuntu' user, copies SSH authorized keys from root to 'ubuntu', and enables passwordless sudo for 'ubuntu' (must be run as root).

## Docker Installer
- **Path**: `scripts/docker.sh`
- **Description**: Checks if Docker is installed; if not, installs it and adds the current user to the 'docker' group.

