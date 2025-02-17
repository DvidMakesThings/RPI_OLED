#!/bin/bash

function powerProfile {
    # Ask if the power supply is capable of delivering the required current
    read -p "Is your power supply capable of delivering the required current without power-delivery negotiation? (yes/no): " response

    if [[ "$response" == "yes" ]]; then
        # Check if the Raspberry Pi model is Raspberry Pi 5
        pi_model=$(cat /proc/device-tree/model)
        if [[ "$pi_model" == *"Raspberry Pi 5"* ]]; then
            # Modify /boot/firmware/config.txt to allow max current
            echo "Modifying /boot/firmware/config.txt to allow max current..."
            sudo bash -c "echo 'usb_max_current_enable=1' >> /boot/firmware/config.txt"

            # Modify EEPROM to allow max current
            echo "Modifying EEPROM to allow max current..."
            sudo rpi-eeprom-config --out /tmp/boot.conf --config /proc/device-tree/hat/custom_0/boot.conf
            echo "PSU_MAX_CURRENT=5000" | sudo tee -a /tmp/boot.conf
            sudo rpi-eeprom-config --apply /tmp/boot.conf

            echo "Setup complete"
        else
            echo "This setting is only applicable to Raspberry Pi 5. No changes made."
        fi
    else
        # Check if the Raspberry Pi model is Raspberry Pi 5
        pi_model=$(cat /proc/device-tree/model)
        if [[ "$pi_model" == *"Raspberry Pi 5"* ]]; then
            # Modify EEPROM to set default max current
            echo "Modifying EEPROM to set default max current..."
            sudo rpi-eeprom-config --out /tmp/boot.conf --config /proc/device-tree/hat/custom_0/boot.conf
            echo "PSU_MAX_CURRENT=" | sudo tee -a /tmp/boot.conf
            sudo rpi-eeprom-config --apply /tmp/boot.conf

            echo "Setup complete with default max current"
        else
            echo "Power-delivery negotiation is needed or power supply is not capable. No changes made."
        fi
    fi
}
 
# Setup static IP address
echo "##################### Setting up static IP address for eth0 #####################"
echo "PLEASE SET UP MANUALLY"
sudo nmtui
echo "Reseting the network manager"
sudo systemctl restart NetworkManager
echo "Static IP address set up complete."

# Setup sytem power 
echo "########################### Setting up power profile ############################"
powerProfile
echo "Power settings complete."

# Update and upgrade system
echo "######################### Updating and upgrading system #########################"
sudo apt update && sudo apt full-upgrade -y
sudo apt update
sudo apt upgrade -y

# Update and install system dependencies
echo "#################### Updating and Installing Required Packages ####################"
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
    python3-dev python3-pip python3-numpy \
    libfreetype6-dev libjpeg-dev build-essential \
    libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev libportmidi-dev \
    libssl-dev libffi-dev zlib1g-dev libsqlite3-dev libbz2-dev libreadline-dev libncurses5-dev \
    libgdbm-dev libnss3-dev liblzma-dev uuid-dev wget git

# Download and install Python 3.12.3
echo "################### Downloading and Installing Python 3.12.3 ####################"
cd /usr/src
sudo wget https://www.python.org/ftp/python/3.12.3/Python-3.12.3.tgz
sudo tar xzf Python-3.12.3.tgz
cd Python-3.12.3
sudo ./configure --enable-optimizations
sudo make -j$(nproc)
sudo make altinstall
python3.12 --version

# Install Git
echo "############################## Installing Git ##################################"
sudo apt install -y git
git --version

# Clone the luma.examples repository to /opt/luma
echo "########################## Setting up I2C Display ##############################"
echo "Cloning luma.examples repository..."
sudo mkdir -p /opt/luma
sudo chown $USER:$USER /opt/luma
cd /opt/luma
git clone https://github.com/rm-hull/luma.examples.git
cd luma.examples

# Enable the I2C interface
echo "Enabling I2C interface..."
sudo raspi-config nonint do_i2c 0

# Create Python virtual environment
echo "######################## Setting Up Virtual Environment ########################"
VENV_DIR="/opt/sys_venv"
sudo mkdir -p $VENV_DIR
sudo chown $USER:$USER $VENV_DIR
python3.12 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

# Install Python dependencies inside the virtual environment
echo "Installing Python dependencies in virtual environment..."
pip install --upgrade pip
pip install luma.oled luma.core

# Create the systemd service file
echo "Creating systemd service..."
SERVICE_FILE="/etc/systemd/system/oled_display.service"

sudo bash -c "cat > $SERVICE_FILE <<EOF
[Unit]
Description=OLED Display Service
After=multi-user.target

[Service]
ExecStart=$VENV_DIR/bin/python3 /opt/luma/luma.examples/examples/sys_info_extended.py
WorkingDirectory=/opt/luma/luma.examples/examples
Restart=always
User=$USER
Group=$USER
Environment=\"PYTHONUNBUFFERED=1\"

[Install]
WantedBy=multi-user.target
EOF"

# Reload systemd and enable the service
echo "Reloading systemd and enabling the service..."
sudo systemctl daemon-reload
sudo systemctl enable oled_display.service

# Start the OLED display service
echo "Starting the OLED display service..."
sudo systemctl start oled_display.service

# Check the service status
echo "Checking the service status..."
sudo systemctl status oled_display.service


# Create folders
echo "########################## Create GitHub Folders ##############################"
mkdir -p /home/$USER/_GitHub
cd /home/$USER/_GitHub
mkdir -p /home/$USER/_GitHub/External
git clone https://github.com/DvidMakesThings/RPi_FastSetup.git
git clone https://github.com/DvidMakesThings/PiVortex.git
cd /PiVortex
chmod -x startslave.sh
chmod -x startApp.sh
cd

sudo reboot now
