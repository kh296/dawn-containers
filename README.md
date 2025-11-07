# Running PyTorch applications on Dawn via Apptainer containers

## 1. Quickstart

The following are minimal instructions for running example PyTorch
model training on Dawn via Apptainer containers, and making use of multi-node
multi-GPU distributed data parallel  The example is for training
classification of hand-written digits from the MNIST dataset.

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

Further information about the example, and about running PyTorch applications
via Apptainer containers is given below.

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
example, additional Python packages can be installed in a [%post]() section,
for example:
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

### 2.3 PyTorch application 
