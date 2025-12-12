Setup Script

This repository contains a setup script that automates the installation of various packages, configuration files, and personal preferences for a clean and efficient Linux setup.

What This Script Does

Installs packages from the Arch Linux repositories and the AUR.

Installs fonts, themes, and icons for a custom look and feel.

Configures the system with custom dotfiles (e.g., .bashrc, .zshrc, .vimrc, .gitconfig).

Configures services and system settings for optimized performance.

Requirements

Arch Linux or an Arch-based distro.

Root privileges: The script needs to be run with sudo to install packages and modify system files.

How to Use
1. Clone the Repository

First, clone the repository to your system:

git clone https://github.com/KEIROFPS/Dotfiles-For-my-cachyos-install-/
cd my-setup-scripts

2. Review the Script (Optional but Recommended)

Before running the script, it's a good idea to review the script.sh to ensure it does what you want. Open it in any text editor:

nano script.sh

3. Run the Script

To run the script and apply the setup:

sudo bash script.sh


The script will:

Prompt you for confirmation before proceeding.

Update your system and install the required packages.

Copy over your configuration files (e.g., .bashrc, .zshrc, .gitconfig, etc.).

Set up fonts, themes, and other personal preferences.

4. Follow Post-Installation Instructions

Once the script has finished, you may need to manually apply themes and icons:

Apply the Monochrome KDE Global Theme and Bibata Original Classic cursor from System Settings > Appearance > Global Theme and Cursors.

Apply the Snowy icon theme in System Settings > Appearance > Icons.

5. Reboot or Log Out

After the script finishes, it's a good idea to reboot your system or log out and back in for the changes to take full effect.

Troubleshooting

If the script fails or you encounter any issues, the log file located at /tmp/install_log.txt will contain detailed information about what went wrong.

You can also check if any packages failed to install by reviewing the output during script execution.

Custom Configuration Files

The configs/ directory contains several default configuration files (e.g., .bashrc, .zshrc, .vimrc, .gitconfig). If you want to customize these files further:

Modify the files in the configs/ directory.

Push the changes to your GitHub repository.

When others run the script, these files will be copied into their home directories automatically.

Example Directory Structure

Here's what the structure of this repository should look like:

my-setup-scripts/
├── script.sh         # The setup script
└── configs/          # Directory with configuration files
    ├── .bashrc
    ├── .zshrc
    ├── .vimrc
    ├── .gitconfig
    └── ... (other config files)
