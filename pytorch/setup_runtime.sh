# Script to set environment variables for running inside container.

# Ensure definition of environment variables
# used both at apptainer launch and at runtime.
source setup_shared.sh

# Leave PATH and LD_LIBRARY_PATH as they are if not in container.
if [[ ${LD_LIBRARY_PATH} != *"singularity"* ]]; then
    exit
fi

# Define PATH and LD_LIBRARY_PATH
# so as to allow host MPI installation to be used in container.
CCL_DIR=${ONEAPI_DIR}/intel-oneapi-ccl-2021.15.0-j6k6sz2dychtpxv52ealp2lv44wyf2e7
MPI_DIR=${ONEAPI_DIR}/intel-oneapi-mpi-2021.15.0-ufie2hgmtafkbg5iwtful2da6vmhpsif
CCL_CCL_DIR=${CCL_DIR}/ccl/2021.15
CCL_MPI_DIR=${CCL_DIR}/mpi/2021.15
CCL_MPI_FAB_DIR=${CCL_MPI_DIR}/opt/mpi/libfabric
MPI_MPI_DIR=${MPI_DIR}/mpi/2021.15
MPI_MPI_FAB_DIR=${MPI_MPI_DIR}/opt/mpi/libfabric

export PATH=${CCL_MPI_DIR}/bin:${MPI_MPI_DIR}/bin:${SLURM_DIR}/sbin:${SLURM_DIR}/bin:${GLOBAL_DIR}/bin:${PATH}
export LD_LIBRARY_PATH=${CCL_CCL_DIR}/lib:${CCL_MPI_FAB_DIR}/lib:${CCL_MPI_DIR}/lib:${MPI_MPI_FAB_DIR}/lib:${MPI_MPI_DIR}/lib:${SLURM_DIR}/lib:${GLOBAL_DIR}/lib:/usr/lib64:/usr/lib64/libibverbs:${LD_LIBRARY_PATH}
