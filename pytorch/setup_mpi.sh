# Script to set environment variables useful for task parallelisation with MPI.
# These include variables used by Intel libraries, and variables derived
# from variables typically set in a Slurm environment.  Default values are
# used for any Slurm variables that are missing.
#
# The derived variables specifying number of tasks per node (TASKS_PER_NODE),
# number of tasks (WORLD_SIZE), and number of CPU cores per task
# (CPUS_PER_TASK) depend on the number of nodes allocated, on the
# number of GPUs per node, and on how GPUs are configured.
#
# On Dawn (hostname *pvc-s*), if a single node is allocated,
# then it may be allocated with 1, 2, 3, or 4 GPUs (but not with 0 GPUs).
# If more than one node is allocated, all must be allocated with all (4) GPUs.
# If GPUs are used in "FLAT" mode, the two stacks of each GPU are treated as two
# root devices.  If GPUs are used in "COMPOSITE" mode, the two stacks
# of each GPU are treated as a single root device.  For more information
# about modes for Intel GPUs, see:
# https://www.intel.com/content/www/us/en/docs/oneapi/optimization-guide-gpu/2024-1/exposing-device-hierarchy.html
# https://www.intel.com/content/www/us/en/developer/articles/technical/flattening-gpu-tile-hierarchy.html
#
# The variables specifying node(s) allocated (SLURM_JOB_NODELIST)
# and job id (SLURM_JOB_ID) are used to define the master address (MASTER_ADDR)
# and port (MASTER_PORT) for task parallelisation.

# Default to 1 node allocated if running outside of Slurm.
if [[ -z "${SLURM_NNODES}" ]]; then
    SLURM_NNODES=1
fi

# Determine number of root devices per GPU.
if [[ "$(hostname)" == "pvc-s"* ]]; then
    if [[ "COMPOSITE" == ${ZE_FLAT_DEVICE_HIERARCHY} ]]; then
        DEVICES_PER_GPU=1
    else
	ZE_FLAT_DEVICE_HIERARCHY="FLAT"
        DEVICES_PER_GPU=2
    fi
    export ZE_FLAT_DEVICE_HIERARCHY
else
    DEVICES_PER_GPU=1
fi

# Determine number of tasks per node, with one task per GPU root device,
# or defaulting to 1 if there are no GPUs.
# On Dawn, set affinity mask to match number of root devices.
if [[ -z "${SLURM_GPUS_ON_NODE}" ]]; then
    TASKS_PER_NODE=1
else
    TASKS_PER_NODE=$((${SLURM_GPUS_ON_NODE}*${DEVICES_PER_GPU}))
    if [[ "$(hostname)" == "pvc-s"* ]]; then
        if [[ ${TASKS_PER_NODE} -gt 1 ]]; then
            ZE_AFFINITY_MASK=$(seq -s, 0 $((${TASKS_PER_NODE}-1)))
        else
            ZE_AFFINITY_MASK=0
        fi
        export ZE_AFFINITY_MASK
    fi
fi

# Determine total number of tasks.
WORLD_SIZE=$((SLURM_NNODES * TASKS_PER_NODE))

# Determine number of CPU cores per task.
if [[ -z "${SLURM_CPUS_ON_NODE}" ]]; then
    SLURM_CPUS_ON_NODE=1
fi
CPUS_PER_TASK=$((SLURM_CPUS_ON_NODE / TASKS_PER_NODE))

# Ensure that value assigned to SLURM_JOB_NODELIST.
if [[ -z "${SLURM_JOB_NODELIST}" ]]; then
    SLURM_JOB_NODELIST=$(hostname)
fi

# Ensure that a value is assigned to SLURM_JOB_ID.
if [[ -z "${SLURM_JOB_ID}" ]]; then
    export SLURM_JOB_ID=5100
fi

# Create list of node names, and identify first in list as master address.
if command -v scontrol 1>/dev/null 2>&1; then
    NODELIST="$(echo $(scontrol show hostnames ${SLURM_JOB_NODELIST})\
        | sed 's/ /,/g')"
else
    NODELIST="${SLURM_JOB_NODELIST}"
fi
MASTER_ADDR="${NODELIST%%,*}"

# Define master port based on SLURM_JOB_ID.
MASTER_PORT=$(( (SLURM_JOB_ID % 10000) + 50000 ))

# Unset and set Slurm variables.
# This is necessary to allow submission of a Slurm job from a computer node.
unset SLURM_MEM_PER_CPU
unset SLURM_MEM_PER_NODE
SLURM_EXPORT_ENV=ALL

# Define mpi launch command.
MPI_LAUNCH="mpiexec -n ${WORLD_SIZE} -ppn ${TASKS_PER_NODE} --hosts ${NODELIST}"

# Load modules.
module purge
module load rhel9/default-dawn
module load intel-oneapi-ccl/2021.15.0

# Set some oneCCL environment variables.
#
# https://uxlfoundation.github.io/oneCCL/env-variables.html#ccl-log-level
export CCL_LOG_LEVEL="warn"
#
# https://uxlfoundation.github.io/oneCCL/env-variables.html#ccl-process-launcher
export CCL_PROCESS_LAUNCHER="hydra"
#
# https://uxlfoundation.github.io/oneCCL/env-variables.html#ccl-atl-transport
# On Dawn, the recommended value for Abstract Transport Layer (ATL) transport
# is "ofi".
# The value "mpi" may also be used, but tends to result in slower communication.
export CCL_ATL_TRANSPORT="ofi"
#
# https://uxlfoundation.github.io/oneCCL/env-variables.html#ccl-ze-ipc-exchange
# With the current setup_apptainer.sh, the only mechanism enabled
# for Level Zero Inter Process Communication (IPC) exchange is "sockets".
export CCL_ZE_IPC_EXCHANGE="sockets"
#
# https://uxlfoundation.github.io/oneCCL/env-variables.html#ccl-atl-shm
# Set to 1 if "shm" is to be used as fabric provider, by itself or in
# combination with another provider.  Otherwise, set to 0.
export CCL_ATL_SHM=0
#
# https://github.com/uxlfoundation/oneCCL/blob/2021.15/src/topology/topo_manager.cpp#L468
export CCL_TOPO_FABRIC_VERTEX_CONNECTION_CHECK=0
#
# https://www.intel.com/content/www/us/en/docs/oneccl/developer-guide-reference/2021-8/environment-variables.html#MULTI-NIC
# Each Dawn node has 4 network interface cards (NICs).
# Setting the number of NICs used (CCL_MNIC_COUNT) to be greater than 1
# doesn't necessarily increase speed, depending on the data transfers
# performed.
# If the fabric provider (FI_PROVIDER below) is set to "tcp", "shm,tcp",
# "verbs" or "shm,verbs", NIC selection (CCL_MNIC) should be set to "global".
# If the fabric provider is "psm3" or "shm,psm3", NIC selection may be set to
# "local" or "global".
# Within a selection, NICs may be filtered by defining CCL_MNIC_NAME.
export CCL_MNIC_COUNT=1
export CCL_MNIC="global"
#export CCL_MNIC_NAME="ib0"

# Configure Open Fabrics Infrastructure (OFI).
#
# https://www.intel.com/content/www/us/en/docs/mpi-library/developer-guide-linux/2021-6/ofi-providers-support.html
# With the current setup_apptainer.sh, the providers supported, and
# the network-interface cards (NICs) that they use are:
# "tcp" (default) - uses NICs from "eth0", "eth1", "ib0", "ib1", "ib2", "ib3",
#     "lo", defaulting to "eth0" when a single NIC is requested;
# "verbs" - uses Mellanox InfiniBand NICs from "mlx5_0", "mlx5_1",
#     "mlx5_2", "mlx5_3", defaulting to "mlx_0" when a single NIC is requested;
# "psm3" - uses Mellanox InfiniBand NICs from "mlx5_0", "mlx5_1",
#     "mlx5_2", "mlx5_3", defaulting to "mlx_0" when a single NIC is requested;
# "shm" - uses shared memory, available for intra-node communication only,
#     requires CCL_ATL_SHM=1 (see above), may be used in combination with
#     another providers, for example "shm,psm3".
#
# In the case of the example:
# - speeds tend to be in the order "tcp", "psm3", "verbs";
# - speeds with 1 network-interface card tend to be higher than
#   with more than 1.
export FI_PROVIDER="tcp"
# https://www.intel.com/content/www/us/en/docs/mpi-library/developer-reference-linux/2021-15/ofi-capable-network-fabrics-control.html#id-d9184e46
# If CCL_ATL_TRANSPORT is set to "mpi" (not recommended on Dawn),
# I_MPI_OFI_PROVIDER should be set to the same value as FI_PROVIDED.
# In other cases, it's ignored.
export I_MPI_OFI_PROVIDER=${FI_PROVIDER}

# Set MPI debug level.
# https://www.intel.com/content/www/us/en/docs/mpi-library/developer-reference-linux/2021-8/other-environment-variables.html#id-d16918e42
export I_MPI_DEBUG=0
