#!/usr/bin/env bash


# CREATOR: Mike Lu (klu7@lenovo.com)
# CHANGE DATE: 6/18/2025
__version__="1.7"


# Quick Setup For VMWare GPU DPIO (Direct Path I/O) Cert Testing - Ubuntu Environment



# User-defined settings
FILE_DIR="/root/Downloads"
TIME_ZONE='Asia/Taipei'     # MTY/RDC:  US/Eastern
NETMASK='255.255.252.0'     # MTY/RDC:  255.255.255.0 
NETMASK_CIDR='22'           # MTY/RDC:  24
GATEWAY='192.168.4.7'       # MTY/RDC:  192.168.10.10
DNS='10.241.96.14'          # MTY/RDC:  192.168.10.10


# File downlaod URLs 
# (non-HGX)
CUDA_URL="https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run"
CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.6.0/local_installers/11.8/cudnn-local-repo-ubuntu2004-8.6.0.163_1.0-1_amd64.deb"
NV_DRIVER_URL="https://yun.yangwenqing.com/NVIDIA/vGPU/NVIDIA/17.5/NVIDIA-GRID-Linux-KVM-550.144.02-550.144.03-553.62/Guest_Drivers/nvidia-linux-grid-550_550.144.03_amd64.deb"
PIP_URL="https://files.pythonhosted.org/packages/b7/06/6b1ad0ae8f97d7a0d6f6ad640db10780578999e647a9593512ceb6f06469/pip-23.3.2.tar.gz" 
TENSORFLOW_URL="http://files-pythonhosted-org.vr.org/packages/e4/8a/0c38f712159d698e6216a4006bc91b31ce9c3412aaeae262b07f02db1174/tensorflow-2.12.0-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
# (HGX)
HGX_CUDA_URL="https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_570.86.10_linux.run"
HGX_NV_DRIVER_URL="https://yun.yangwenqing.com/NVIDIA/vGPU/NVIDIA/18.0/NVIDIA-GRID-Linux-KVM-570.124.03-570.124.06-572.60/Guest_Drivers/nvidia-linux-grid-570_570.124.06_amd64.deb"
HGX_FABRICMANAGER_URL="http://archive.ubuntu.com/ubuntu/pool/multiverse/f/fabric-manager-570/nvidia-fabricmanager-570_570.124.06-0ubuntu1_amd64.deb"
HGX_TENSORFLOW_URL="https://files.pythonhosted.org/packages/2b/b6/86f99528b3edca3c31cad43e79b15debc9124c7cbc772a8f8e82667fd427/tensorflow-2.19.0-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
HGX_CUDNN_URL="https://huggingface.co/MonsterMMORPG/Generative-AI/resolve/7f3deee733ac9cf811ef0e3e1dd7f40b4f8ca5ea/cudnn-local-repo-ubuntu2204-8.9.7.29_1.0-1_amd64.deb"


# File names 
# (non-HGX)
CUDA_FILENAME="cuda_11.8.0_520.61.05_linux.run"
CUDNN_FILENAME="cudnn-local-repo-ubuntu2004-8.6.0.163_1.0-1_amd64.deb"
NV_DRIVER_FILENAME="nvidia-linux-grid-550_550.144.03_amd64.deb"
PIP_FILENAME="pip-23.3.2.tar.gz"
TENSORFLOW_FILENAME="tensorflow-2.12.0-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
# (HGX)
HGX_CUDA_FILENAME="cuda_12.8.0_570.86.10_linux.run"
HGX_CUDNN_FILENAME="cudnn-local-repo-ubuntu2204-8.9.7.29_1.0-1_amd64.deb"
HGX_NV_DRIVER_FILENAME="nvidia-linux-grid-570_570.124.06_amd64.deb"
HGX_TENSORFLOW_FILENAME="tensorflow-2.19.0-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
HGX_FABRICMANAGER_FILENAME="nvidia-fabricmanager-570_570.124.06-0ubuntu1_amd64.deb"


# File versions 
# (non-HGX)
CUDA_VER="11.8"
PIP_DIR="pip-23.3.2"
# (HGX)
HGX_CUDA_VER="12.8"


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
    
# Ensure there's no other dpkg process running behind    
Kill_dpkg_process() {
    dpkg_PIDs=$(lsof /var/lib/dpkg/lock-frontend | awk 'NR>1 {print $2}')
    if [[ $dpkg_PIDs ]]; then
      for pid in $dpkg_PIDs; do
        sudo kill -9 $pid
      done
    fi
}

# Set local time zone and reset NTP
CURRENT_TIME_ZONE=$(timedatectl status | grep "Time zone" | awk '{print $3}')
if [ "$CURRENT_TIME_ZONE" != "$TIME_ZONE" ]; then
    sudo timedatectl set-timezone $TIME_ZONE
    sudo ln -sf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime
    sudo timedatectl set-ntp 0 && sleep 1 && timedatectl set-ntp 1
fi


echo "╭─────────────────────────────────────────────────╮"
echo "│   VMware Certification Test Environment Setup   │"
echo "│       GPU VMDirectPath I/O (DPIO) - Ubuntu      │"
echo "╰─────────────────────────────────────────────────╯"

# Determine if this is HGX GPU (more than 4 GPUs and 2 NVSwiches)
GPU_COUNT=$(lspci -nn | grep -i nvidia | grep -i '3D controller' | wc -l)
NVIDIA_BRIDGE_COUNT=$(lspci -nn | grep -i nvidia | grep -i 'Bridge' | wc -l)
if (( GPU_COUNT == 4 || GPU_COUNT == 8 || GPU_COUNT > 8 )); then
    if (( NVIDIA_BRIDGE_COUNT >= 2 )); then
        HGX=true
        echo -e "\nThis is HGX GPU\n"
    fi
fi

# Blacklist NVIDIA open-source VGA driver
echo
echo "--------------------------------"
echo "BLOCK NVIDIA OPEN SOURCE DRIVER"
echo "--------------------------------"
echo
if [[ $(lsmod | grep nouveau) ]] && [[ ! $(grep -w 'blacklist nouveau' /etc/modprobe.d/blacklist.conf) ]]; then
    echo 'blacklist nouveau' >> /etc/modprobe.d/blacklist.conf
    update-initramfs -u
    
    # For RHEL
    # sudo echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
    # sudo echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist-nouveau.conf
    # sudo dracut --force
    [[ $? == 0 ]] && systemctl reboot || { echo "❌ Failed to blacklist NV driver"; exit 1; }
else
    echo -e "\n✅ Nouveau driver is blacklisted\n"
fi
	
  
# Set network config
echo
echo "------------------------"
echo "CONFIG INTERNET NETWORK"
echo "------------------------"
echo
NIC=`ip a | grep -B1 'link/ether' | grep -v 'link/ether' | awk -F ': ' '{print $2}'`  # eg. ens34 (assuming only one NIC exposed)
NIC_NAME=`nmcli connection | grep 'ethernet' | tail -1 | awk -F '  ' '{print $1}'` # eg. Wired connection 1  (assuming only one NIC exposed)  
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
    read -p "  Input IP address: " NEW_IP  # eg. 192.168.7.130
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
echo "--------------------------------"
echo "INSTALL DKMS & PYTHON LIBRARIES"
echo "--------------------------------"
echo
for lib in dkms python3-setuptools; do
    if ! dpkg -l | grep -q "$lib"; then
    apt update && apt install $lib -y || { echo "❌ Failed to install $lib"; exit 1; }
fi
done
echo -e "\n✅ Python setuptools and dkms already installed"
	
    
# Download Cuda/Cudnn/Driver/pip/tensorflow
echo
echo "---------------"
echo "DOWNLOAD TOOLS"
echo "---------------"
echo
mkdir -p $FILE_DIR
if [[ "$HGX" == false ]]; then
    for file in $CUDA_FILENAME $CUDNN_FILENAME $NV_DRIVER_FILENAME $PIP_FILENAME $TENSORFLOW_FILENAME; do
        if [[ ! -f "$FILE_DIR/$file" ]]; then
            if [[ $file == $CUDA_FILENAME ]]; then
                wget -P $FILE_DIR $CUDA_URL && echo -e "\n✅ Cuda toolkit is downloaded" || { echo -e "\n❌ Downloading Cuda toolkit failed"; exit 1; } 
            fi
            if [[ $file == $CUDNN_FILENAME ]]; then
                wget -P $FILE_DIR $CUDNN_URL && echo -e "\n✅ cuDNN is downloaded" || { echo -e "\n❌ Downloading cuDNN failed"; exit 1; }
            fi
            if [[ $file == $NV_DRIVER_FILENAME ]]; then
                wget -P $FILE_DIR $NV_DRIVER_URL && echo -e "\n✅ NV vGPU driver is downloaded" || { echo -e "\n❌ Downloading NV vGPU driver failed"; exit 1; } 
            fi
            if [[ $file == $PIP_FILENAME ]]; then
                wget -P $FILE_DIR $PIP_URL && echo -e "\n✅ Pip is downloaded" || { echo -e "\n❌ Downloading pip failed"; exit 1; }
            fi
            if [[ $file == $TENSORFLOW_FILENAME ]]; then
                wget -P $FILE_DIR $TENSORFLOW_URL && echo -e "\n✅ Tensorflow is downloaded" || { echo -e "\n❌ Downloading tensorflow failed"; exit 1; } 
            fi
        else
            echo -e "✅ "$file" already exists, skipping download."  
        fi
    done
elif [[ "$HGX" == true ]]; then
    for file in $HGX_CUDA_FILENAME $HGX_CUDNN_FILENAME $HGX_NV_DRIVER_FILENAME $HGX_FABRICMANAGER_FILENAME $PIP_FILENAME $HGX_TENSORFLOW_FILENAME; do
        if [[ ! -f "$FILE_DIR/$file" ]]; then
            if [[ $file == $HGX_CUDA_FILENAME ]]; then
                wget -P $FILE_DIR $HGX_CUDA_URL && echo -e "\n✅ Cuda toolkit is downloaded" || { echo -e "\n❌ Downloading Cuda toolkit failed"; exit 1; } 
            fi
            if [[ $file == $HGX_CUDNN_FILENAME ]]; then
                wget -P $FILE_DIR $HGX_CUDNN_URL && echo -e "\n✅ cuDNN is downloaded" || { echo -e "\n❌ Downloading cuDNN failed"; exit 1; }
            fi
            if [[ $file == $HGX_NV_DRIVER_FILENAME ]]; then
                wget -P $FILE_DIR $HGX_NV_DRIVER_URL && echo -e "\n✅ NVIDIA vGPU driver is downloaded" || { echo -e "\n❌ Downloading NVIDIA vGPU driver failed"; exit 1; } 
            fi
            if [[ $file == $PIP_FILENAME ]]; then
                wget -P $FILE_DIR $PIP_URL && echo -e "\n✅ Pip is downloaded" || { echo -e "\n❌ Downloading pip failed"; exit 1; }
            fi
            if [[ $file == $HGX_TENSORFLOW_FILENAME ]]; then
                wget -P $FILE_DIR $HGX_TENSORFLOW_URL && echo -e "\n✅ Tensorflow is downloaded" || { echo -e "\n❌ Downloading tensorflow failed"; exit 1; } 
            fi
            if [[ $file == $HGX_FABRICMANAGER_FILENAME ]]; then
                wget -P $FILE_DIR $HGX_FABRICMANAGER_URL && echo -e "\n✅ NVIDIA fabric manager is downloaded" || { echo -e "\n❌ Downloading NVIDIA fabric manager failed"; exit 1; } 
            fi
        else
            echo -e "✅ "$file" already exists, skipping download."  
        fi
    done
fi


# Check if all files exist (except for the extracted pip folder)
FILE_COUNT=$(find "${FILE_DIR}" -maxdepth 1 -type f | wc -l)
if [[ "$HGX" == false ]]; then
    if [[ $FILE_COUNT != 5 ]]; then
        echo "❌ ${FILE_COUNT} file(s) found in ${FILE_DIR}! (Only 5 files are expected) Please check"
        exit 1
    else
        echo -e "\n✅ All the 5 required files in ${FILE_DIR} found"
    fi
elif [[ "$HGX" == true ]]; then
    if [[ $FILE_COUNT != 6 ]]; then
        echo "❌ ${FILE_COUNT} file(s) found in ${FILE_DIR}! (Only 6 files are expected) Please check"
        exit 1
    else
        echo -e "\n✅ All the 6 required files in ${FILE_DIR} found"
    fi
fi


# Extract tar files
find "$FILE_DIR" -name "*.tar.gz" -exec tar -xf {} -C "$FILE_DIR" \;
    
    
# Install and upgrade pip tool
if ! pip -V &> /dev/null; then
    find "$FILE_DIR" -maxdepth 1 -type d -name "pip-*" | xargs -I {} bash -c 'cd {}; python3 setup.py install' \;
    python3 -m pip install --upgrade pip
else
    echo -e "\n✅ PIP package is already installed"
fi


# Install NV vGPU driver
echo
echo "-----------------------"
echo "INSTALL NV VGPU DRIVER"
echo "-----------------------"
echo
if ! lsmod | grep -i nvidia &> /dev/null; then
    if ! dpkg -l | grep -q 'NVIDIA GRID driver'; then
        Kill_dpkg_process
        if [[ "$HGX" == false ]]; then
            dpkg -i $FILE_DIR/$NV_DRIVER_FILENAME
        elif [[ "$HGX" == true ]]; then
            dpkg -i $FILE_DIR/$HGX_NV_DRIVER_FILENAME
        fi
        if [[ $? == 0 ]]; then
            echo -e "\n✅ NV vGPU driver installed successfully"
            echo "System will automatically reboot after 5 seconds..."
            for n in {5..1}s; do printf "\r$n"; sleep 1; done
            echo
            reboot now
        else
            echo -e "\n❌ Failed to install NV vGPU driver"
            exit 1
        fi
    fi
fi
echo -e "\n✅ NV vGPU driver is already installed"


# Install NVLink service
if [[ "$HGX" == true ]]; then
    echo
    echo "--------------------------"
    echo "INSTALL NV FABRIC MANAGER"
    echo "--------------------------"
    echo
    if ! dpkg -l | grep -q 'nvidia-fabricmanager'; then
        Kill_dpkg_process
        dpkg -i $FILE_DIR/$HGX_FABRICMANAGER_FILENAME
        [[ $? == 0 ]] && echo -e "\n✅ NV fabric manager installed successfully" || { echo -e "\n❌ Failed to install NV fabric manager"; exit 1; }
    else
        echo -e "\n✅ NV fabric manager is already installed"
    fi
fi


# Install CUDA toolkit
echo
echo "---------------------"
echo "INSTALL CUDA TOOLKIT"
echo "---------------------"
echo
if command -v nvcc &> /dev/null; then
    CUDA_INSTALLED=true
else
    CUDA_INSTALLED=false
fi
if [[ "$CUDA_INSTALLED" == "false" ]]; then
    if [[ "$HGX" == false ]]; then
        bash $FILE_DIR/$CUDA_FILENAME --silent --toolkit || { echo -e "\n❌ Failed to install CUDA toolkit"; exit 1; }
        echo "export PATH=/usr/local/cuda-$CUDA_VER/bin:\$PATH" >> ~/.bashrc
        echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDA_VER/lib64:\$LD_LIBRARY_PATH" >> ~/.bashrc
        # Set env virable for the current console
        export PATH=/usr/local/cuda-$CUDA_VER/bin:$PATH
        export LD_LIBRARY_PATH=/usr/local/cuda-$CUDA_VER/lib64:$LD_LIBRARY_PATH   
    elif [[ "$HGX" == true ]]; then
        bash $FILE_DIR/$HGX_CUDA_FILENAME --silent --toolkit || { echo -e "\n❌ Failed to install CUDA toolkit"; exit 1; }
        echo "export PATH=/usr/local/cuda-$HGX_CUDA_VER/bin:\$PATH" >> ~/.bashrc
        echo "export LD_LIBRARY_PATH=/usr/local/cuda-$HGX_CUDA_VER/lib64:\$LD_LIBRARY_PATH" >> ~/.bashrc
    
        # Set env virable for the current console
        export PATH=/usr/local/cuda-$HGX_CUDA_VER/bin:$PATH
        export LD_LIBRARY_PATH=/usr/local/cuda-$HGX_CUDA_VER/lib64:$LD_LIBRARY_PATH
    fi
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


# Run CUDA sample test
echo
echo "------------------"
echo "QUERY CUDA DEVICE"
echo "------------------"
echo
command -v git &> /dev/null || sudo apt install git -y
[[ ! -d ./cuda-samples ]] && git clone https://github.com/NVIDIA/cuda-samples.git
[[ ! -f ./cuda-samples/Samples/1_Utilities/deviceQuery/deviceQuery ]] && nvcc ./cuda-samples/Samples/1_Utilities/deviceQuery/deviceQuery.cpp -o ./cuda-samples/Samples/1_Utilities/deviceQuery/deviceQuery -I ./cuda-samples/Common/
./cuda-samples/Samples/1_Utilities/deviceQuery/deviceQuery
[[ $? == 0 ]] && echo -e "\n✅ CUDA sample test passed" || { echo -e "\n❌ CUDA sample test failed"; exit 1; }



# Install CUDNN
echo
echo "--------------"
echo "INSTALL CUDNN"
echo "--------------"
echo
if ! dpkg -l | grep -q 'cudnn-local'; then
    Kill_dpkg_process
    if [[ "$HGX" == false ]]; then
        CUDNN_DIR_NAME=`echo $CUDNN_FILENAME | awk -F '_' '{print $1}'` # eg. cudnn-local-repo-ubuntu2004-8.6.0.163
        dpkg -i $FILE_DIR/$CUDNN_FILENAME
    elif [[ "$HGX" == true ]]; then    
        CUDNN_DIR_NAME=`echo $HGX_CUDNN_FILENAME | awk -F '_' '{print $1}'` # eg. cudnn-local-repo-ubuntu2204-8.8.0.121
        dpkg -i $FILE_DIR/$HGX_CUDNN_FILENAME
    fi
    if [[ $? != 0 ]]; then
        echo -e "\n❌ Failed to install cuDNN, please check the package"
        exit 1
    fi
    CUDNN_PATH="/var/$CUDNN_DIR_NAME"
    CUDNN_DEB_VER=`ls $CUDNN_PATH/libcudnn* | awk -F '_' '{print $2}' | tail -1`  # eg. 8.6.0.163-1+cuda11.8
    cp $CUDNN_PATH/cudnn-local*keyring.gpg /usr/share/keyrings/  # eg. cudnn-local-B0FE0A41-keyring.gpg
    
    
    apt update
    apt install libcudnn8=$CUDNN_DEB_VER libcudnn8-dev=$CUDNN_DEB_VER libcudnn8-samples=$CUDNN_DEB_VER -y
    if [[ $? != 0 ]]; then
        echo -e "\n❌ Failed to install cuDNN libraries"
        exit 1
    else
        echo -e "\n✅ cuDNN installed successfully"
    fi
else
    echo -e "\n✅ cuDNN is already installed"
fi
    
    
# Configure CUDNN
echo
echo "-------------"
echo "CONFIG CUDNN"
echo "-------------"
echo
cp -r /usr/src/cudnn_samples*/ $HOME  # eg. cudnn_samples_v8
cd $HOME/cudnn_samples*/mnistCUDNN
for lib in libfreeimage3 libfreeimage-dev; do
    if ! dpkg -l | grep -q "$lib"; then
        apt install $lib -y || { echo -e "\n❌ Error installing $lib"; exit 1; }
    fi
done
make clean && make
./mnistCUDNN
[[ $? == 0 ]] && echo -e "\n✅ cuDNN configuration passed" || { echo -e "\n❌ cuDNN configuration failed"; exit 1; }


# Install tensorflow
echo
echo "-------------------"
echo "INSTALL TENSORFLOW"
echo "-------------------"
echo
if ! pip list | grep "tensorflow" > /dev/null; then
    if [[ "$HGX" == false ]]; then
        pip3 install $FILE_DIR/$TENSORFLOW_FILENAME
    elif [[ "$HGX" == true ]]; then    
        pip3 install $FILE_DIR/$HGX_TENSORFLOW_FILENAME
    fi
    if [[ $? != 0 ]]; then
        echo -e "\n❌ Failed to install Tensorflow module"
        exit 1
    else
        echo -e "\n✅ Tensorflow module installed successfully"
    fi
else
    echo -e "\n✅ Tensorflow module is already installed"
fi


# Check if tensorflow module is usable in python
echo
echo "-------------------------"
echo "VERIFY TENSORFLOW MODULE"
echo "-------------------------"
echo
python3 -c "import tensorflow as tf"
if [[ $? == 0 ]]; then
    echo -e "\n✅ Tensorflow module can be imported successfully"
else
    echo -e "\n❌ Tensorflow module can't be imported successfully" && exit 1
fi


# Install python3.8 for 22.04 + ESXi8.0 cert
if [[ "$HGX" == true ]]; then
    echo
    echo "-------------------"
    echo "INSTALL PYTHON 3.8"
    echo "-------------------"
    echo
    PY_VER=`python3 -V 2>&1 | awk '{print $2}' | cut -d. -f1-2`
    if [[ $PY_VER != 3.8 ]]; then
        if ! find /etc/apt/sources.list.d/ -maxdepth 1 -type f -name "deadsnakes-*" | grep -q .; then
            sudo add-apt-repository ppa:deadsnakes/ppa -y
            sudo apt update
        fi
        sudo apt install python3.8 python3.8-distutils -y
        sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 200
        for py_ver_path in /usr/bin/python3.*; do
            py_ver_name=$(basename "$py_ver_path") # e.g., python3.10
            py_major_minor=$(echo "$py_ver_name" | cut -d'.' -f2) # e.g., 10 for 3.10
            if [[ "$py_ver_name" != "python3.8" ]]; then
                sudo update-alternatives --install /usr/bin/python3 python3 "$py_ver_path" $((100 + py_major_minor))
            fi
        done
        sudo update-alternatives --set python3 /usr/bin/python3.8
        sudo mkdir -p /usr/lib/python3.8/dist-packages
        sudo ln -s /usr/lib/python3/dist-packages/apt_pkg.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.8/dist-packages/apt_pkg.so 
    else
        echo -e "\n✅ Python 3.8 is already installed and set as default"
    fi
fi


# Re-install and upgrade pip tool
if [[ "$HGX" == true ]]; then
    echo
    echo "-----------------------------"
    echo "REINSTALL PIP FOR PYTHON 3.8"
    echo "-----------------------------"
    echo
    if ! pip -V &> /dev/null; then
        sudo apt install python3-pip -y
        python3 -m pip install --upgrade pip
        pip index versions tensorflow | grep -q 2.6.0
        [[ $? == 0 ]] && echo -e "\n✅ PIP package for Python3.8 is installed" || { echo -e "\n❌ Failed to install PIP package for Python3.8"; exit 1; }
    else
        echo -e "\n✅ PIP package is already installed"
    fi
fi


echo
echo "---------"
echo "COMPLETED"
echo "----------"
echo
echo -e "\n\e[32mAll set! You are okay to go :)\e[0m\n"


exit

