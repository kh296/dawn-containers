# Running PyTorch applications in containers on Dawn

## 1. Quickstart

The following are minimal instructions for running example PyTorch
model training on Dawn, using muldi-node multi-GPU distributed data
parallel with containers.  The example is for training classification of
hand-written digits from the MNIST dataset.

It's possible to work either on a Dawn login node or on a Dawn compute node.

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
