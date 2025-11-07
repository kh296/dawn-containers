# Script to set environment variables for apptainer launch.

# Ensure definition of environment variables
# used both at apptainer launch and at runtime.
source setup_shared.sh

# Load modules.
module purge
module load rhel9/default-dawn
module load intel-oneapi-ccl/2021.15.0

# Perform environment setup.
export CCL_ATL_TRANSPORT="ofi"
export CCL_ZE_IPC_EXCHANGE="sockets"
export CCL_TOPO_FABRIC_VERTEX_CONNECTION_CHECK=0

# Define host paths to be bound when launching apptainer.
export APPTAINER_BINDPATH="\
/etc/libibverbs.d,\
/usr/lib64/libefa.so.1,\
/usr/lib64/libibverbs,\
/usr/lib64/libibverbs.so.1,\
/usr/lib64/libmlx5.so.1.25.54.0,\
/usr/lib64/libnuma.so.1,\
/usr/lib64/libpsm2.so.2,\
/usr/lib64/librdmacm.so.1,\
/usr/lib64/libucm.so.0,\
/usr/lib64/libucp.so.0,\
/usr/lib64/libucs.so.0,\
/usr/lib64/libuct.so.0,\
/usr/local/dawn/software/spack-rocky9/opt-dawn-2025-03-23/linux-rocky9-sapphirerapids/oneapi-2025.1.0,\
/usr/local/software/slurm/current-rhel9,\
/usr/local/software/global-rhel9
"

# Define apptainer and mpi launch commands.
APPTAINER_IMAGE="pytorch2.8.sif"
APPTAINER_LAUNCH="apptainer exec ${APPTAINER_IMAGE}"
MPI_LAUNCH="mpiexec -n ${WORLD_SIZE} -ppn ${TASKS_PER_NODE} --hosts ${NODELIST}"
