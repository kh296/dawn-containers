# Running PyTorch applications in containers on Dawn

## Quickstart

The following are minimal instructions for running example PyTorch
model training on Dawn, using muldi-node multi-GPU distributed data
parallel with containers.  The example is for training classification of
hand-written digits from the MNIST dataset.

Working either from a Dawn login node or from a Dawn compute node:
- Clone this repository, and move to the `pytorch` directory:
```
clone https://github.com/kh296/dawn-containers
cd pytorch
```

From a Dawn login node, substituting a valid project account
for `<project_account>`:
- Submit a Slurm job to build the Apptainer image:
  ```
  sbatch --account=<project_account> build_image.sh
  ```
  This writes output to `build_image.log`, and creates an image file
  `pytorch2.8.sif`.
- Once the image-build job has completed, submit a Slurm job to run the PyTorch
  example:
  ```
  sbatch --account=<project_account> go_apptainer.sh
  ```
  This writes output to `go_apptainer.log`.

From a Dawn compute node, submit Slurm jobs in the same way as on a login node,
or run scripts interactively:
- Build the Apptainer image:
  ```
  ./build_image.sh
  ```
  This writes output to terminal (`stdout`), and creates an image file
  `pytorch2.8.sif`.
- Run the PyTorch example:
  ```
  ./go_apptainer.sh
  ```
  This writes output to terminal (`stdout`).
