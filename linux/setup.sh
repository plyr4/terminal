#!/bin/sh
set -x
# This file is intended to be ran when setting up a new linux distribution
WD=$(pwd) # record workdir

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

# install go1.17.6
cd /tmp
wget https://go.dev/dl/go1.17.6.linux-amd64.tar.gz --output-document=go1.17.6.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.17.6.linux-amd64.tar.gz
# 'export PATH' exists and belongs in .bash_profile or .bashrc
export PATH=$PATH:/usr/local/go/bin
go version
cd $WD

# install docker
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