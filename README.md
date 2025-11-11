# Running PyTorch applications on Dawn via Apptainer containers

## 1. Quickstart

The following are minimal instructions for running example PyTorch
model training on the [Dawn supercomputer](https://www.hpc.cam.ac.uk/d-w-n) via
[Apptainer](https://apptainer.org/docs/user/main/index.html)
containers, and making use of multi-node
multi-GPU [distributed data parallel](https://docs.pytorch.org/tutorials/beginner/ddp_series_intro.html?utm_source=distr_landing&utm_medium=ddp_series_intro).
The example is for training
classification of hand-written digits from the [MNIST dataset](https://web.archive.org/web/20200430193701/http://yann.lecun.com/exdb/mnist/).

Instructions are provided for working on a Dawn login node and on
a Dawn compute node.

### 1.1 On a Dawn login node

- Clone this repository, and move to the `pytorch` directory:
  ```
  clone https://github.com/kh296/dawn-containers
  cd pytorch
  ```
- Submit a Slurm job to create the Apptainer image file `pytorch2.8.sif`:
  ```
  # Substitute valid project account for <project_account>.
  # Output written to build_image.log.
  sbatch --account=<project_account> build_image.sh
  ```
- Once the image-build job has completed, submit a Slurm job to run the PyTorch
  example:
  ```
  # Substitute valid project account for <project_account>.
  # Output written to build_imag.log
  sbatch --account=<project_account> go_apptainer.sh
  ```

### 1.2 On a Dawn compute node

Follow the same steps as on a Dawn login node, or execute scripts interactively
rather than submitting as Slurm jobs:

- Clone this repository, and move to the `pytorch` directory:
  ```
  clone https://github.com/kh296/dawn-containers
  cd pytorch
  ```
- Create the Apptainer image file `pytorch2.8.sif`:
  ```
  ./build_image.sh
  ```
- Run the PyTorch example:
  ```
  ./go_apptainer.sh
  ```

## 2. Further information

### 2.1 Apptainer image

The script [pytorch/build_image.sh](pytorch/build_image.sh) builds an
Apptainer image, `pytorch2.8.sif`, as specified by
a definition file, [pytorch/pytorch2.8.def](pytorch/pytorch2.8.def).  The
build is from the Docker image
[intel/intel-extension-for-pytorch:2.8.10-xpu](https://hub.docker.com/r/intel/intel-extension-for-pytorch).
This includes drivers for Intel GPUs, and an installation of
[PyTorch 2.8](https://github.com/pytorch/pytorch/tree/v2.8.0) together with
[Intel Extension for PyTorch](https://intel.github.io/intel-extension-for-pytorch/xpu/2.8.10+xpu/).

The definition file may be modified, following the instructions for
[Apptainer definition files](https://apptainer.org/docs/user/main/definition_files.html), so as to create an image with additional functionality.  For
example, additional Python packages can be installed in a
[%post](https://apptainer.org/docs/user/main/definition_files.html#post)
section, for example:
```
%post
    export PIP_ROOT_USER_ACTION=ignore;
    export PIP_NO_CACHE_DIR=1;
    python -m pip install --upgrade pip;
    python -m pip install matplotlib;
    python -m pip install pandas;
    python -m pip install seaborn;
```

### 2.2 Environment setup

Two scripts are used to set the environment for distributed processing
via containers:

- [pytorch/setup_mpi.sh](pytorch/setup_mpi.sh)

  This script determines the resources available for distributed processing,
  based on the values of
  [Slurm environment variables](https://slurm.schedmd.com/sbatch.html#SECTION_OUTPUT-ENVIRONMENT-VARIABLES),
  and on the [device hierarchy](https://www.intel.com/content/www/us/en/docs/oneapi/optimization-guide-gpu/2024-1/exposing-device-hierarchy.html) chosen
  (environment variable `ZE_FLAT_DEVICE_HIERARCY` set to `"COMPOSITE"`
  or `"FLAT"`).  In particular, it determines values for:
  - `NODELIST`: list of names of allocated nodes;
  - `TASKS_PER_NODE`: number of GPU root devices per node;
  - `CPUS_PER_TASK`: number of CPU cores allocated per GPU root device;
  - `WORLD_SIZE`: total number of GPU devices allocated;
  - `MASTER_ADDR`: address of the node coordinating distributed processing;
  - `MASTER_PORT`: port on coordinating node for communication with
    distributed processes.
  A GPU root device is a GPU card for `"COMPOSITE"` hierarchy, and is a
  GPU stack for `"FLAT"` hierarchy.  (Dawn has two stacks per GPU card.)
  Each GPU root device is used for a separate processing task.

  In addition, this script loads modules for enabling MPI on the node
  from which it's sourced, sets non-default values for some of the
  environment variables that affect MPI behaviour, and defines an MPI
  launch command that will use all allocated resources:
  ```
  MPI_LAUNCH="mpiexec -n ${WORLD_SIZE} -ppn ${TASKS_PER_NODE} --hosts ${NODELIST}"
  ```

- [pytorch/setup_apptainer.sh](pytorch/setup_apptainer.sh)

  This script sources [pytorch/setup_mpi.sh](pytorch/setup_mpi.sh),
  and defines paths on the node (host) where a container is launched that
  need to be mapped to container paths, using [bind mounts]
  (https://apptainer.org/docs/user/main/bind_paths_and_mounts.html).  This
  [allows the MPI installation of the host to be used from inside the container]
  (https://apptainer.org/docs/user/main/mpi.html#bind-model).

Except for `PATH` and `LD_LIBRARY_PATH`, each container inherits the
environment of the process from which its launched.  This has the advantage
that environment variables for MPI communication are set automatically.

### 2.3 PyTorch application 
