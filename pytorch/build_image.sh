#!/bin/bash -l
#SBATCH --job-name=build_image # create a short name for the job
#SBATCH --output=%x.log        # job output file
#SBATCH --partition=pvc9       # cluster partition to be used
#SBATCH --nodes=1              # number of nodes
#SBATCH --gres=gpu:1           # number of allocated gpus per node
#SBATCH --time=00:15:00        # total run time limit (HH:MM:SS)

# Script for building Apptainer image from Docker image that has
# PyTorch installed with Intel extensions and GPU drivers.
# For information about the Docker image, see:
# https://hub.docker.com/r/intel/intel-extension-for-pytorch

# This script can be run interactively on a Dawn compute node or login node:
#     ./build_apptainer_image.sh
# or can be submitted to Dawn's Slurm batch system, substituting a
# valid project account for <project_account>:.
#     sbatch --acount=<project_account> ./build_apptainer_image.sh

apptainer build --force pytorch2.8.sif pytorch2.8.def
