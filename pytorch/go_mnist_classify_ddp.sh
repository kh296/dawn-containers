#!/bin/bash

# Script to run a single instance of an example of pytorch model training.
# The example is for training classification of hand-written digets
# from the MNIST dataset.

# Set up runtime environment.
source setup_runtime.sh

# Define and execute run command.
CMD="\
python mnist_classify_ddp.py\
 --ntasks-per-node ${TASKS_PER_NODE}\
 --dist-url ${MASTER_ADDR}\
 --dist-port ${MASTER_PORT}\
 --cpus-per-task ${CPUS_PER_TASK}\
 --epochs 2\
"

echo "${CMD}"
eval ${CMD}
