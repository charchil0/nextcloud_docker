#!/bin/bash

# Function to check if .env file is configured
check_env_file() {
    if [[ ! -f ".env" ]]; then
        echo "Error: .env file not found in the current directory."
        exit 1
    fi
}

read -p "$(tput setaf 6)Note that this installation is only for local nextcloud setup. If you want to setup nextcloud for https,refer to this repo: {https://github.com/ichiTechs/Dockerized-SSL-NextCloud-with-MariaDB.git} 

Before installing, please ensure the environment variable that includes the database passwords is configured in the .env file in this directory. Is it already configured (y/n)? $(tput sgr0)" proceed

if [[ "$proceed" != "y" ]]; then
    echo "Installation aborted."
    exit 1
fi

check_env_file

# Function to identify the package manager
package_manager() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                echo "apt"
                ;;
            fedora)
                echo "dnf"
                ;;
            centos|rhel)
                echo "yum"
                ;;
            opensuse|sles)
                echo "zypper"
                ;;
            arch)
                echo "pacman"
                ;;
            *)
                echo "unsupported"
                ;;
        esac
    else
        echo "unsupported"
    fi
}

# Function to install Docker and Docker Compose based on the package manager
install_docker_and_compose() {
    local pm=$(package_manager)

    case "$pm" in
        apt)
            echo "Updating package list..."
            sudo apt update -y || { echo "Failed to update package list"; exit 1; }
            echo "Installing Docker dependencies..."
            sudo apt install -y apt-transport-https ca-certificates curl software-properties-common || { echo "Failed to install dependencies"; exit 1; }
            echo "Adding Docker's official GPG key..."
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - || { echo "Failed to add GPG key"; exit 1; }
            echo "Adding Docker repository..."
            sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || { echo "Failed to add repository"; exit 1; }
            echo "Updating package list again..."
            sudo apt update -y || { echo "Failed to update package list"; exit 1; }
            echo "Installing Docker..."
            sudo apt install -y docker-ce || { echo "Failed to install Docker"; exit 1; }

            echo "Installing Docker Compose..."
            sudo apt install -y docker-compose || { echo "Failed to install Docker Compose"; exit 1; }
            ;;

        dnf)
            echo "Updating package list..."
            sudo dnf makecache || { echo "Failed to update package list"; exit 1; }
            echo "Installing Docker..."
            sudo dnf install -y dnf-plugins-core || { echo "Failed to install plugins"; exit 1; }
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || { echo "Failed to add repo"; exit 1; }
            sudo dnf install -y docker-ce || { echo "Failed to install Docker"; exit 1; }

            echo "Installing Docker Compose..."
            sudo dnf install -y docker-compose || { echo "Failed to install Docker Compose"; exit 1; }
            ;;

        yum)
            echo "Updating package list..."
            sudo yum check-update || { echo "Failed to check updates"; exit 1; }
            echo "Installing Docker dependencies..."
            sudo yum install -y yum-utils device-mapper-persistent-data lvm2 || { echo "Failed to install dependencies"; exit 1; }
            echo "Adding Docker repository..."
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || { echo "Failed to add repo"; exit 1; }
            echo "Installing Docker..."
            sudo yum install -y docker-ce || { echo "Failed to install Docker"; exit 1; }

            echo "Installing Docker Compose..."
            sudo yum install -y docker-compose || { echo "Failed to install Docker Compose"; exit 1; }
            ;;

        zypper)
            echo "Updating package list..."
            sudo zypper refresh || { echo "Failed to refresh zypper"; exit 1; }
            echo "Installing Docker..."
            sudo zypper install -y docker || { echo "Failed to install Docker"; exit 1; }

            echo "Installing Docker Compose..."
            sudo zypper install -y docker-compose || { echo "Failed to install Docker Compose"; exit 1; }
            ;;

        pacman)
            echo "Updating package list..."
            sudo pacman -Syu --noconfirm || { echo "Failed to update packages"; exit 1; }
            echo "Installing Docker..."
            sudo pacman -S --noconfirm docker || { echo "Failed to install Docker"; exit 1; }

            echo "Installing Docker Compose..."
            sudo pacman -S --noconfirm docker-compose || { echo "Failed to install Docker Compose"; exit 1; }
            ;;

        unsupported)
            echo "Unsupported distribution or package manager."
            exit 1
            ;;
    esac

    echo "$(tput setaf 2)Docker and Docker Compose installation completed successfully!$(tput sgr0)"
}

install_docker_and_compose

echo "$(tput setaf 6)Starting Docker services...$(tput sgr0)"
if ! systemctl is-active --quiet docker; then
    sudo systemctl start docker 
    sudo systemctl enable docker 
fi

if ! systemctl is-active --quiet docker.socket; then
    sudo systemctl start docker.socket 
    sudo systemctl enable docker.socket 
fi

echo "$(tput setaf 6)Adding $USER to the docker group...$(tput sgr0)"
sudo usermod -aG docker "$USER"
echo "$(tput setaf 3)You may need to log out and back in for group changes to take effect.$(tput sgr0)"

echo "$(tput setaf 6)Setting up Portainer...$(tput sgr0)"
docker volume create portainer_data
docker run -d -p 9000:9000 --name portainer --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data portainer/portainer-ce:2.11.0

echo "$(tput setaf 6)Composing the Nextcloud setup...$(tput sgr0)"
if [[ ! -f "./docker-compose.yml" ]]; then
    echo "$(tput setaf 1)Error: docker-compose.yml file not found!$(tput sgr0)"
    exit 1
fi

docker-compose up -d || { 
    echo "$(tput setaf 1)Error occurred while starting Nextcloud with docker-compose.$(tput sgr0)"
    exit 1 
}

echo "$(tput setaf 2)Installation Summary:$(tput sgr0)"
echo "$(tput setaf 2)Portainer is installed. Access it at: http://localhost:9000$(tput sgr0)"
echo "$(tput setaf 2)Nextcloud setup is completed. Access it at: http://localhost:8080.$(tput sgr0)"
echo "$(tput setaf 3)If the setup page doesn't show up after a few moments, please try restarting your system.$(tput sgr0)"
