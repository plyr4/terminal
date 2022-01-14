#!/bin/sh
# This file is intended to be ran when setting up a new linux distribution

# ensure apt is up to date
sudo apt-get update

# install some essential apt packages
sudo apt-get install -y \
    build-essential \
    ca-certificates \
    chromium-browser \
    colordiff \
    curl \
    git \
    gnupg \
    gnome-tweaks \
    gtk2-engines-murrine \
    gtk2-engines-pixbuf \
    lsb-release \
    libssl-dev \
    nginx \
    tmux \
    tree \
    vim \
    xclip

# install python
sudo apt-get install python3.6

# install docker
WD=$(pwd) # record workdir
cd /tmp # move to tmp
# download and run docker install script from https://get.docker.com
wget https://get.docker.com --output-document=install_docker.sh && \
chmod +x install_docker.sh && \
./install_docker.sh && \
rm -rf install_docker.sh
cd $WD # return to original workdir

# ubuntu themes
mkdir -p ~/.themes ~/.icons
cd ~/.themes
git clone https://github.com/EliverLara/Ant-Bloody.git
cd $WD # return to original workdir