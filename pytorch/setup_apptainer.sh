# Script to set environment variables for apptainer launch.

# Set environment variables relating to MPI.
source setup_mpi.sh

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
/usr/local/dawn/software/spack-rocky9/opt-dawn-2025-03-23/linux-rocky9-sapphirerapids/oneapi-2025.1.0\
"
