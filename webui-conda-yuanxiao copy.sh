#!/usr/bin/env bash
#################################################
# Please do not make any changes to this file,  #
# change the variables in webui-user.sh instead #
#################################################



install_dir="/home/$(whoami)"
clone_dir="stable-diffusion-webui"
python_cmd="python3"
export GIT="git"

LAUNCH_SCRIPT="launch.py"

# this script cannot be run as root by default
can_run_as_root=0
# read any command line flags to the webui.sh script
while getopts "f" flag > /dev/null 2>&1
do
    case ${flag} in
        f) can_run_as_root=1;;
        *) break;;
    esac
done

# Disable sentry logging
export ERROR_REPORTING=FALSE

# Do not reinstall existing pip packages on Debian/Ubuntu
export PIP_IGNORE_INSTALLED=0

# Pretty print
delimiter="################################################################"

printf "\n%s\n" "${delimiter}"
printf "\e[1m\e[32mInstall script for stable-diffusion + Web UI\n"
printf "\e[1m\e[34mTested on Debian 11 (Bullseye)\e[0m"
printf "\n%s\n" "${delimiter}"

# Do not run as root
if [[ $(id -u) -eq 0 && can_run_as_root -eq 0 ]]
then
    printf "\n%s\n" "${delimiter}"
    printf "\e[1m\e[31mERROR: This script must not be launched as root, aborting...\e[0m"
    printf "\n%s\n" "${delimiter}"
    exit 1
else
    printf "\n%s\n" "${delimiter}"
    printf "Running on \e[1m\e[32m%s\e[0m user" "$(whoami)"
    printf "\n%s\n" "${delimiter}"
fi

if [[ -d .git ]]
then
    printf "\n%s\n" "${delimiter}"
    printf "Repo already cloned, using it as install directory"
    printf "\n%s\n" "${delimiter}"
    install_dir="${PWD}/../"
    clone_dir="${PWD##*/}"
fi

# Check prerequisites
gpu_info=$(lspci 2>/dev/null | grep VGA)
case "$gpu_info" in
    *"Navi 1"*|*"Navi 2"*) export HSA_OVERRIDE_GFX_VERSION=10.3.0
    ;;
    *"Renoir"*) export HSA_OVERRIDE_GFX_VERSION=9.0.0
        printf "\n%s\n" "${delimiter}"
        printf "Experimental support for Renoir: make sure to have at least 4GB of VRAM and 10GB of RAM or enable cpu mode: --use-cpu all --no-half"
        printf "\n%s\n" "${delimiter}"
    ;;
    *) 
    ;;
esac
if echo "$gpu_info" | grep -q "AMD" && [[ -z "${TORCH_COMMAND}" ]]
then
    export TORCH_COMMAND="pip install torch torchvision --extra-index-url https://download.pytorch.org/whl/rocm5.2"
fi  

for preq in "${GIT}" "${python_cmd}"
do
    if ! hash "${preq}" &>/dev/null
    then
        printf "\n%s\n" "${delimiter}"
        printf "\e[1m\e[31mERROR: %s is not installed, aborting...\e[0m" "${preq}"
        printf "\n%s\n" "${delimiter}"
        exit 1
    fi
done

cd "${install_dir}"/ || { printf "\e[1m\e[31mERROR: Can't cd to %s/, aborting...\e[0m" "${install_dir}"; exit 1; }
if [[ -d "${clone_dir}" ]]
then
    printf "hahha------"
    cd "${clone_dir}"/ || { printf "\e[1m\e[31mERROR: Can't cd to %s/%s/, aborting...\e[0m" "${install_dir}" "${clone_dir}"; exit 1; }
else
    printf "\n%s\n" "${delimiter}"
    printf "Clone stable-diffusion-webui"
    printf "\n%s\n" "${delimiter}"
    "${GIT}" clone https://github.com/yuan6785/stable-diffusion-webui "${clone_dir}"
    cd "${clone_dir}"/ && git checkout 39bf8e1ad4e9ba35f7848bd1e8974292a9460025 || { printf "\e[1m\e[31mERROR: Can't cd to %s/%s/, aborting...\e[0m" "${install_dir}" "${clone_dir}"; exit 1; }
fi

printf "\n%s\n" "${delimiter}"
printf "Create and activate python venv"
printf "\n%s\n" "${delimiter}"
cd "${install_dir}"/"${clone_dir}"/ || { printf "\e[1m\e[31mERROR: Can't cd to %s/%s/, aborting...\e[0m" "${install_dir}" "${clone_dir}"; exit 1; }
# if [[ ! -d "${venv_dir}" ]]
# then
#     "${python_cmd}" -m venv "${venv_dir}"
#     first_launch=1
# fi
# shellcheck source=/dev/null
# if [[ -f "${venv_dir}"/bin/activate ]]
# then
#     source "${venv_dir}"/bin/activate
# else
#     printf "\n%s\n" "${delimiter}"
#     printf "\e[1m\e[31mERROR: Cannot activate python venv, aborting...\e[0m"
#     printf "\n%s\n" "${delimiter}"
#     exit 1
# fi

# add by yx
# need yx create conda env ： conda create --name sd_python310 python=3.10
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/sd3/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/sd3/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/sd3/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/sd3/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
conda init
conda activate sd_python310
# end --- by yx

if [[ ! -z "${ACCELERATE}" ]] && [ ${ACCELERATE}="True" ] && [ -x "$(command -v accelerate)" ]
then
    printf "\n%s\n" "${delimiter}"
    printf "Accelerating launch.py..."
    printf "\n%s\n" "${delimiter}"
    exec accelerate launch --num_cpu_threads_per_process=6 "${LAUNCH_SCRIPT}" "$@"
else
    printf "\n%s\n" "${delimiter}"
    printf "Launching launch.py..."
    printf "\n%s\n" "${delimiter}"      
    exec "${python_cmd}" "${LAUNCH_SCRIPT}" "$@"
fi