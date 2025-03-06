#!/usr/bin/env bash


# CREATOR: Mike Lu (klu7@lenovo.com)
# CHANGE DATE: 3/6/2025
__version__="1.1"


# **Quick setup for Ubuntu VM environment of VMWare Cert testing**


# User-defined settings
FILE_DIR="/root/Downloads"
TIME_ZONE='Asia/Taipei'
NETMASK='22'  # 255.255.252.0
GATEWAY='192.168.4.7'
DNS='10.241.96.14'



# [CUDA Toolkit source page] https://developer.nvidia.com/cuda-11-8-0-download-archive
CUDA_URL="https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run"
CUDA_FILENAME="cuda_11.8.0_520.61.05_linux.run"
CUDA_VER="11.8"

# [CUDNN source page 1] https://developer.nvidia.com/rdp/cudnn-archive (*need NV account) 
# [CUDNN source page 2] https://developer.download.nvidia.com/compute/redist/cudnn
CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.6.0/local_installers/11.8/cudnn-local-repo-ubuntu2004-8.6.0.163_1.0-1_amd64.deb"
CUDNN_FILENAME="cudnn-local-repo-ubuntu2004-8.6.0.163_1.0-1_amd64.deb"
    
# [NV vGPU Driver source page] https://docs.nvidia.com/vgpu/latest/grid-vgpu-release-notes-ubuntu/index.html (*need NV account) 
NV_DRIVER_URL="https://alist.geekxw.top/d/NVIDIA-GRID-Linux-KVM-550.127.06-550.127.05-553.24/Guest_Drivers/nvidia-linux-grid-550_550.127.05_amd64.deb?sign=KoqcPNr1rTPnideVdfdLuV_upkkk9YYI4DF6QYI208o=:0"
NV_DRIVER_FILENAME="nvidia-linux-grid-550_550.127.05_amd64.deb"
    
# [PIP source page] https://pypi.org/project/pip/#history
PIP_URL="https://files.pythonhosted.org/packages/b7/06/6b1ad0ae8f97d7a0d6f6ad640db10780578999e647a9593512ceb6f06469/pip-23.3.2.tar.gz" 
PIP_FILENAME="pip-23.3.2.tar.gz"
PIP_DIR="pip-23.3.2"
   
# [Tensorflow source page 1] https://tensorflow.google.cn/install/source?hl=zh-tw#linux
# [Tensorflow source page 2] http://104.225.11.179/project/tensorflow/2.12.0/#files
TENSORFLOW_URL="http://files-pythonhosted-org.vr.org/packages/e4/8a/0c38f712159d698e6216a4006bc91b31ce9c3412aaeae262b07f02db1174/tensorflow-2.12.0-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
TENSORFLOW_FILENAME="tensorflow-2.12.0-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
    



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
    echo -e "\n✅ Nouveau driver is blacklisted"
fi
	
  
# Set network config
echo
echo "--------------------------"
echo "CONFIG INTERNET NETWORK..."
echo "--------------------------"
echo
read -p "  Enter the IP address to access Internet: " NEW_IP  # ex: 192.168.7.130
NIC=`ip a | grep -B1 'link/ether' | grep -v 'link/ether' | awk -F ': ' '{print $2}'`  # ex: ens34
NIC_NAME=`nmcli connection | tail -1 | awk -F '  ' '{print $1}'` # Wired connection 1        
if ! nmcli connection modify "$NIC_NAME" ipv4.method manual ipv4.addresses "$NEW_IP"/"$NETMASK" ipv4.gateway "$GATEWAY" ipv4.dns "$DNS" 2>/dev/null; then
    echo -e "\n❌ Failed to configure network interface!"
    exit 1
fi
nmcli connection down "$NIC_NAME" > /dev/null
sleep 2
nmcli connection up "$NIC_NAME" > /dev/null
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
for file in $CUDA_FILENAME $CUDNN_FILENAME $NV_DRIVER_FILENAME $PIP_FILENAME $TENSORFLOW_FILENAME; do
    if [[ ! -f "$FILE_DIR/$file" ]]; then
        if [[ $file == $CUDA_FILENAME ]]; then
            wget -P $FILE_DIR $CUDA_URL && echo -e "\n✅ Cuda toolkit is downloaded" || { echo -e "\n❌ Downloading Cuda toolkit failed"; exit 1; } 
        fi
        if [[ $file == $CUDNN_FILENAME ]]; then
            wget -P $FILE_DIR $CUDNN_URL && echo -e "\n✅ cuDNN is downloaded" || { echo -e "\n❌ Downloading cuDNN failed"; exit 1; }
        fi
        if [[ $file == $NV_DRIVER_FILENAME ]]; then
            wget -P $FILE_DIR -O $FILE_DIR/$NV_DRIVER_FILENAME $NV_DRIVER_URL && echo -e "\n✅ NV vGPU driver is downloaded" || { echo -e "\n❌ Downloading NV vGPU driver failed"; exit 1; } 
        fi
        if [[ $file == $PIP_FILENAME ]]; then
            wget -P $FILE_DIR $PIP_URL && echo -e "\n✅ Pip is downloaded" || { echo -e "\n❌ Downloading pip failed"; exit 1; }
        fi
        if [[ $file == $TENSORFLOW_FILENAME ]]; then
            wget -P $FILE_DIR $TENSORFLOW_URL && echo -e "\n✅ Tensorflow is downloaded" || { echo -e "\n❌ Downloading tensorflow failed"; exit 1; } 
        fi
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

