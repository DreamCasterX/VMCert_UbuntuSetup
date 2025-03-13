#!/usr/bin/env bash


# CREATOR: Mike Lu (klu7@lenovo.com)
# CHANGE DATE: 3/13/2025
__version__="1.2"


# Quick Setup For VMWare GPU DPIO (Direct Path I/O) Cert Testing - Ubuntu Environment


# User-defined settings
FILE_DIR="/root/Downloads"
TIME_ZONE='Asia/Taipei'
NETMASK='255.255.252.0'
NETMASK_CIDR='22'
GATEWAY='192.168.4.7'
DNS='10.241.96.14'
CUDA_VER="11.8"
PIP_DIR="pip-23.3.2"


# Download URLs
urls=(
  # CUDA Toolkit
  # Source: https://developer.nvidia.com/cuda-11-8-0-download-archive
  'https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run'
  
  # CUDNN
  # Source1: https://developer.nvidia.com/rdp/cudnn-archive (*need NV account) 
  # Source2: https://developer.download.nvidia.com/compute/redist/cudnn
  'https://developer.download.nvidia.com/compute/redist/cudnn/v8.6.0/local_installers/11.8/cudnn-local-repo-ubuntu2004-8.6.0.163_1.0-1_amd64.deb'
  
  # NV vGPU Driver
  # Source: https://docs.nvidia.com/vgpu/latest/grid-vgpu-release-notes-ubuntu/index.html (*need NV account) 
  'https://alist.geekxw.top/d/NVIDIA-GRID-Linux-KVM-550.127.06-550.127.05-553.24/Guest_Drivers/nvidia-linux-grid-550_550.127.05_amd64.deb?sign=KoqcPNr1rTPnideVdfdLuV_upkkk9YYI4DF6QYI208o=:0'
  
  # PIP 
  # Source: https://pypi.org/project/pip/#history
  'https://files.pythonhosted.org/packages/b7/06/6b1ad0ae8f97d7a0d6f6ad640db10780578999e647a9593512ceb6f06469/pip-23.3.2.tar.gz'
  
  # Tensorflow
  # Source1: https://tensorflow.google.cn/install/source?hl=zh-tw#linux  
  # Source2: http://104.225.11.179/project/tensorflow/2.12.0/#files
  'http://files-pythonhosted-org.vr.org/packages/e4/8a/0c38f712159d698e6216a4006bc91b31ce9c3412aaeae262b07f02db1174/tensorflow-2.12.0-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl'
)


# Color settings
yellow='\e[93m'
nc='\e[0m'


# Check Internet connection
CheckInternet() {
    ! wget -q --spider www.google.com > /dev/null && echo -e "❌ No Internet connection! Check your network and retry.\n" && exit || :
}

# Ensure the user is running the script as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️ Please login as root to run this script"
    exit 1
fi
    

# Set local time zone and reset NTP
timedatectl set-timezone $TIME_ZONE
ln -sf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime
timedatectl set-ntp 0 && sleep 1 && timedatectl set-ntp 1


echo "╭─────────────────────────────────────────────────╮"
echo "│   VMware Certification Test Environment Setup   │"
echo "│       GPU VMDirectPath I/O (DPIO) - Ubuntu      │"
echo "╰─────────────────────────────────────────────────╯"
# Blacklist NVIDIA open-source VGA driver
echo
echo "----------------------------------"
echo "BLOCK NVIDIA OPEN SOURCE DRIVER..."
echo "----------------------------------"
echo
if [[ $(lsmod | grep nouveau) ]] && [[ ! $(grep -w 'blacklist nouveau' /etc/modprobe.d/blacklist.conf) ]]; then
    echo 'blacklist nouveau' >> /etc/modprobe.d/blacklist.conf
    update-initramfs -u
    [[ $? == 0 ]] && systemctl reboot || { echo "❌ Failed to blacklist NV driver"; exit 1; }
else
    echo -e "\n✅ Nouveau driver is blacklisted\n"
fi
	
  
# Set network config
echo
echo "--------------------------"
echo "CONFIG INTERNET NETWORK..."
echo "--------------------------"
echo
NIC=`ip a | grep -B1 'link/ether' | grep -v 'link/ether' | awk -F ': ' '{print $2}'`  # ex: ens34 (assuming only one NIC exposed)
NIC_NAME=`nmcli connection | grep 'ethernet' | tail -1 | awk -F '  ' '{print $1}'` # ex: Wired connection 1  (assuming only one NIC exposed)  
CUR_IP=`nmcli connection show "$NIC_NAME" | grep "IP4.ADDRESS\[1\]:" | awk '{print $2}' | cut -d "/" -f1` 
CUR_NETMASK_CIDR=`nmcli connection show "$NIC_NAME" | grep "IP4.ADDRESS\[1\]:" | awk '{print $2}' | cut -d "/" -f2`  
# Convert CIDR format to traditional format
convert_cidr_to_mask() {
    local cidr=$1
    local mask=""
    if ! [[ "$cidr" =~ ^[0-9]+$ ]]; then
        echo "--"
        return
    fi 
    local full_octets=$(($cidr / 8))
    local remainder_bits=$(($cidr % 8))
    for ((i=0; i<$full_octets; i++)); do
        mask="$mask.255"
    done
    if [ $remainder_bits -gt 0 ]; then
        local remainder_mask=$((256 - 2**(8-$remainder_bits)))
        mask="$mask.$remainder_mask"
    fi
    for ((i=$full_octets+($remainder_bits>0?1:0); i<4; i++)); do
        mask="$mask.0"
    done
    echo ${mask:1}
}
CUR_NETMASK=$(convert_cidr_to_mask $CUR_NETMASK_CIDR)
CUR_GATEWAY=`nmcli connection show "$NIC_NAME" | grep "ipv4.gateway:" | awk '{print $2}'`
CUR_DNS=`nmcli connection show "$NIC_NAME" | grep "ipv4.dns:" | awk '{print $2}'`

echo -e "NIC: ${yellow}"$NIC"${nc}"
echo -e "IP: ${yellow}"$CUR_IP"${nc}"
echo -e "Netmask: ${yellow}"$CUR_NETMASK"${nc}" 
echo -e "Gateway: ${yellow}"$CUR_GATEWAY"${nc}"
echo -e "DNS: ${yellow}"$CUR_DNS"${nc}"
echo 

read -p "Use the current network settings? (y/n) " ans
while [[ "$ans" != [YyNn] ]]; do 
    read -p "Use the current network settings? (y/n) " ans
done

if [[ "$ans" == [Nn] ]]; then
    read -p "  Input IP address: " NEW_IP  # ex: 192.168.7.130
    read -p "  Input Netmask <press Enter to accept default [$NETMASK]>: " NEW_NETMASK
    if [[ -z "$NEW_NETMASK" ]]; then
        NEW_NETMASK=$NETMASK_CIDR
    elif [[ $NEW_NETMASK =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Convert traditional netmask to CIDR format
        case $NEW_NETMASK in
            "255.255.255.0") NEW_NETMASK="24" ;;
            "255.255.254.0") NEW_NETMASK="23" ;;
            "255.255.252.0") NEW_NETMASK="22" ;;
            "255.255.248.0") NEW_NETMASK="21" ;;
            "255.255.240.0") NEW_NETMASK="20" ;;
            "255.255.224.0") NEW_NETMASK="19" ;;
            "255.255.192.0") NEW_NETMASK="18" ;;
            "255.255.128.0") NEW_NETMASK="17" ;;
            "255.255.0.0")   NEW_NETMASK="16" ;;
            "255.0.0.0")     NEW_NETMASK="8" ;;
            *) echo "Unrecognized netmask format. Using default [$NETMASK]"
               NEW_NETMASK=$NETMASK_CIDR ;;
        esac
    fi
    read -p "  Input Gateway <press Enter to accept default [$GATEWAY]>: " NEW_GATEWAY
    if [[ -z "$NEW_GATEWAY" ]]; then
        NEW_GATEWAY=$GATEWAY
    fi
    read -p "  Input DNS <press Enter to accept default [$DNS]>: " NEW_DNS
    if [[ -z "$NEW_DNS" ]]; then
        NEW_DNS=$DNS
    fi

    # Set up connection
    if ! nmcli connection modify "$NIC_NAME" ipv4.method manual ipv4.addresses "$NEW_IP"/"$NEW_NETMASK" ipv4.gateway "$NEW_GATEWAY" ipv4.dns "$NEW_DNS" 2>/dev/null; then
        echo -e "\n❌ Failed to configure network interface!"
        exit 1
    fi
    nmcli connection down "$NIC_NAME" > /dev/null
    sleep 2
    nmcli connection up "$NIC_NAME" > /dev/null
fi

CheckInternet
echo -e "\n✅ Internet access is configured"

	
# Install required libraries
echo
echo "----------------------------------"
echo "INSTALL DKMS & PYTHON LIBRARIES..."
echo "----------------------------------"
echo
for lib in dkms python3-setuptools; do
    if ! dpkg -l | grep "$lib" > /dev/null; then
    apt update && apt install $lib -y || { echo "❌ Failed to install $lib"; exit 1; }
fi
done
echo -e "\n✅ Python setuptools and dkms installed"
	
    
# Download Cuda/Cudnn/Driver/pip/tensorflow
echo
echo "-----------------"
echo "DOWNLOAD TOOLS..."
echo "-----------------"
echo
if [[ ! -d "$FILE_DIR" ]]; then
  mkdir -p "$FILE_DIR"
fi
for url in "${urls[@]}"; do
  filename=$(basename "$url")
  if [[ ! -f "$FILE_DIR/$filename" ]]; then
    wget -P "$FILE_DIR" "$url" && echo -e "✅ \"$filename\" is downloaded" || { echo -e "\n❌ Downloading \"$filename\" failed (error code: $?)"; exit 1; }
  else
    echo -e "✅ \"$filename\" already exists, skipping download."
  fi
done


# Check if all files exist (except for the extracted pip folder)
FILE_COUNT=$(find $FILE_DIR -maxdepth 1 -type f -not -path "$FILE_DIR/$PIP_DIR*" | wc -l)
if [[ $FILE_COUNT != 5 ]]; then
    echo "❌ Missing $((5-$FILE_COUNT)) file(s). Please check"
    exit 1
else
    echo -e "\n✅ All the 5 required files in $FILE_DIR found"
fi

# Extract tar files
find "$FILE_DIR" -name "*.tar.gz" -exec tar -xf {} -C "$FILE_DIR" \;
    
    
# Install and upgrade pip tool
if [[ ! `pip -V` ]]; then
    find "$FILE_DIR" -maxdepth 1 -type d -name "pip-*" | xargs -I {} bash -c 'cd {}; python3 setup.py install' \;
    python3 -m pip install --upgrade pip
else
    echo -e "\n✅ PIP package is installed"
fi


# Install NV vGPU driver
echo
echo "-------------------------"
echo "INSTALL NV VGPU DRIVER..."
echo "-------------------------"
echo
if [[ ! `lsmod | grep -i nvidia` ]]; then
    if [[ ! `dpkg -l | grep 'NVIDIA GRID driver'` ]]; then
        dpkg -i $FILE_DIR/$NV_DRIVER_FILENAME
        [[ $? == 0 ]] && systemctl reboot || { echo -e "\n❌ Failed to install NV driver"; exit 1; }
    fi
else
    echo -e "\n✅ NV vGPU driver is installed"
fi
    


# Install CUDA toolkit
if command -v nvcc &> /dev/null; then
    CUDA_INSTALLED=true
else
    CUDA_INSTALLED=false
fi
if [[ "$CUDA_INSTALLED" == "false" ]]; then
    bash $FILE_DIR/$CUDA_FILENAME || { echo -e "\n❌ Failed to install CUDA toolkit"; exit 1; }
    echo "export PATH=/usr/local/cuda-$CUDA_VER/bin:\$PATH" >> ~/.bashrc
    echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDA_VER/lib64:\$LD_LIBRARY_PATH" >> ~/.bashrc
    
    # Set env virable for the current console
    export PATH=/usr/local/cuda-$CUDA_VER/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda-$CUDA_VER/lib64:$LD_LIBRARY_PATH
    
    # Check if CUDA tooklit is installed
    if command -v nvcc &> /dev/null; then
        echo -e "\n✅ CUDA toolkit installed successfully"
    else
        echo -e "\n⚠️ CUDA installation completed, but nvcc command not found."
        echo "Please run 'source ~/.bashrc' or restart your terminal to update environment variables."
    fi
else
    echo -e "\n✅ CUDA toolkit is already installed"
fi


# Install CUDNN
echo
echo "----------------"
echo "INSTALL CUDNN..."
echo "----------------"
echo
CUDNN_DIR_NAME=`echo $CUDNN_FILENAME | awk -F '_' '{print $1}'` # ex: cudnn-local-repo-ubuntu2004-8.6.0.163
if [[ ! `dpkg -l | grep 'cudnn-local'` ]]; then
    dpkg -i $FILE_DIR/$CUDNN_FILENAME
    if [[ $? != 0 ]]; then
        echo -e "\n❌ Failed to install cuDNN, please check the package"
        exit 1
    fi
    CUDNN_PATH="/var/$CUDNN_DIR_NAME"
    CUDNN_DEB_VER=`ls $CUDNN_PATH/libcudnn* | awk -F '_' '{print $2}' | tail -1`  # ex: 8.6.0.163-1+cuda11.8
    cp $CUDNN_PATH/cudnn-local*keyring.gpg /usr/share/keyrings/  # ex: cudnn-local-B0FE0A41-keyring.gpg
    apt update
    apt install libcudnn8=$CUDNN_DEB_VER libcudnn8-dev=$CUDNN_DEB_VER libcudnn8-samples=$CUDNN_DEB_VER -y
else
    echo -e "\n✅ cuDNN is installed"
fi
    
    
# Configure CUDNN
cp -r /usr/src/cudnn_samples*/ $HOME  # ex: cudnn_samples_v8
cd $HOME/cudnn_samples*/mnistCUDNN
for lib in libfreeimage3 libfreeimage-dev; do
    if ! dpkg -l | grep "$lib" > /dev/null; then
        apt install $lib -y || { echo -e "\n❌ Error installing $lib"; exit 1; }
    fi
done
make clean && make
./mnistCUDNN
    

# Install tensorflow
echo
echo "---------------------"
echo "INSTALL TENSORFLOW..."
echo "---------------------"
echo
if ! pip list | grep "tensorflow" > /dev/null; then
    pip3 install $FILE_DIR/$TENSORFLOW_FILENAME
    if [[ $? != 0 ]]; then
        echo -e "\n❌ Failed to install Tensorflow module"
        exit 1
    fi
else
    echo -e "\n✅ Tensorflow module is installed"
fi


# Check if tensorflow module is usable in python
echo
echo "---------------------------"
echo "VERIFY TENSORFLOW MODULE..."
echo "---------------------------"
echo
python3 -c "import tensorflow as tf"
if [[ $? == 0 ]]; then
    echo -e "\n✅ Tensorflow module can be imported successfully"
else
    echo -e "\n❌ Tensorflow module can't be imported successfully" && exit 1
fi

echo
echo "---------"
echo "COMPLETED"
echo "----------"
echo
echo -e "\n\e[32mAll set! You are okay to go :)\e[0m\n"


exit

