# Scripts ✨

Welcome to **Scripts**, a project that allows you to **generate SSH commands** from a friendly **web UI**!  
Manage your servers, run handy scripts remotely, and streamline your dev operations.

---

## 🚀 How It Works

Go to the [WebUI](https://rohittp.com/scripts/)

1. **Enter Your SSH Params**  
     - **PEM File Path** (Default: `~/.ssh/`)
     - **SSH User** (Default: `root`)
     - **IP/Domain** (e.g., `example.com`)
     - **Port** (Default: `22`)  

2. **Select a Script**  
   - Choose from the scripts listed.  
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

## Nginx Installer
- **Path**: `scripts/nginx.sh`
- **Description**: Installs nginx, enables and starts the nginx service. Also installs certbot for nginx.

## Create SSH Key
- **Path**: `scripts/create_ssh_key.sh`
- **Description**: Creates an SSH key at ~/.ssh/$1, adds it to the SSH agent, and prints the public key.

## Password-less Sudo Setup
- **Path**: `scripts/password_less_sudo.sh`
- **Description**: Enables sudo access and password-less sudo access for the provided user.

## Add SSH Key
- **Path**: `scripts/add_ssh_key.sh`
- **Description**: Adds the provided SSH public key to the authorized_keys file.

## Mount SSH-FS
- **Path**: `scripts/network_fs.sh`
- **Description**: Mounts a remote SSH filesystem using sshfs at the specified mount point. If a user is not specified, it defaults to the current user.

## Swap Setup
- **Path**: `scripts/swap.sh`
- **Description**: Creates and configures a swap file on Ubuntu. Default swap size is 2GB and swappiness is 10. Swappiness controls how aggressively the kernel swaps memory pages (lower = less swapping).

