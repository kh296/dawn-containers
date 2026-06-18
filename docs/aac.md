# Running PyTorch applications on AMD Accelerator Cluster via Apptainer containers

## 1. Introduction
With some small changes, listed below, the instructions for running PyTorch
applications on Dawn via Apptainer containers
([dawn-containers/README.md](../README.md)) can be followed also
for running on the [AMD Accelerator Cluster](https://aac.amd.com/help/).   
For more information about logging in to the AMD Accelerator Cluster, see:
[AAC login info](https://github.com/amd/HPCTrainingExamples/tree/main/login_info/AAC).

## 2. Changes compared with running on Dawn

1. When submitting the example scripts as Slurm jobs on AAC, it's usually not
   necessary to specify the account, but it is necessary to specify the
   partition, and the resources.  The submission commands on AAC6 corresponding
   to those given in
   [1.1 On a Dawn login node](../README.md#11-on-a-dawn-login-node) are:
   ```
   # Submit a Slurm job to create the Apptainer image file.
   sbatch --partition=1CN192C4G1H_MI300A_Ubuntu22  --cpus-per-gpu=48 ./pytorch_apptainer_build.sh
   ```
   ```
   # Submit a Slurm job to run the PyTorch example.
   sbatch --partition=1CN192C4G1H_MI300A_Ubuntu22  --exclusive ./pytorch_apptainer_build.sh
   ```

2. The information about device hierarchy given in
   [2.2 Environment setup](../README.md#22-environment-setup) is specific
   to Dawn, and should be ignored in the context of AAC.

3. Intel MPI and oneCCL, referrenced in
   [2.2 Environment setup](../README.md#22-environment-setup), are replaced
   on AAC by [Open MPI](https://www.open-mpi.org/) and
   [NCCL](https://developer.nvidia.com/nccl), with the latter used via
   the [NCCL Net plugin API](https://rocm.docs.amd.com/projects/rccl/en/develop/how-to/using-nccl.html).

4. All other information in [dawn-containers/README.md](../README.md) about
   running PyTorch applications in containers on Dawn applies also to
   running on AAC.
