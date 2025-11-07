#!/bin/bash -l
#SBATCH --job-name=go_apptainer # create a short name for the job
#SBATCH --output=%x.log         # job output file
#SBATCH --partition=pvc9        # cluster partition to be used
#SBATCH --nodes=2               # number of nodes
#SBATCH --gres=gpu:4            # number of allocated gpus per node
#SBATCH --time=01:00:00         # total run time limit (HH:MM:SS)

# Script for running example pytorch model training on Dawn,
# using multi-node multi-GPU distributed data parallel with containers.
# The example is for training classification of hand-written digets
# from the MNIST dataset.
#
# This script can be run interactively on a Dawn compute node:
#     ./go_apptainer.sh
# or can be submitted to Dawn's Slurm batch system, substituting a
# valid project account for <project_account>:.
#     sbatch --acount=<project_account> ./go_apptainer.sh

T0=${SECONDS}
echo "Job start on $(hostname): $(date)"

# Exit at first failure.
set -e

# Set up environment for launching container.
source setup_apptainer.sh

# Ensure that data needed are downloaded before running application.
if [ ! -d data ]; then
    echo ""
    echo "Downloading dataset"
    T1=${SECONDS}
    PYTHON_DOWNLOAD_LAUNCH="python -c \"import torchvision as tv; tv.datasets.MNIST('data', download=True)\""
    CMD="${APPTAINER_LAUNCH} ${PYTHON_DOWNLOAD_LAUNCH}"
    echo "${CMD}"
    eval "${CMD}"
    echo "Time downloading dataset: $((${SECONDS}-${T1})) seconds"
fi

# Run and time application.
T2=${SECONDS}
CMD="${MPI_LAUNCH} ${APPTAINER_LAUNCH} ./go_mnist_classify_ddp.sh"
echo ""
echo "PyTorch DDP run started: $(date)"
echo "${CMD}"
eval "${CMD}"
echo ""
echo "PyTorch DDP run completed: $(date)"
echo "Run time: $((${SECONDS}-${T2})) seconds"
echo ""
echo "Job time: $((${SECONDS}-${T0})) seconds"
