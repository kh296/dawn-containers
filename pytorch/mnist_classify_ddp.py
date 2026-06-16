import argparse
import importlib
import math
import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torchvision import datasets, transforms
from torch.optim.lr_scheduler import StepLR

# PyTorch XCCL backend enabled with Intel Extension for PyTorch v2.8.10+xpu.
if (not hasattr(torch.distributed, "is_xccl_available")):
    torch.distributed.is_xccl_available = lambda: False
if not torch.distributed.is_xccl_available():
    try:
        import oneccl_bindings_for_pytorch
    except ModuleNotFoundError:
        pass

import os
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from socket import gethostname

class Net(nn.Module):
    def __init__(self):
        super(Net, self).__init__()
        self.conv1 = nn.Conv2d(1, 32, 3, 1)
        self.conv2 = nn.Conv2d(32, 64, 3, 1)
        self.dropout1 = nn.Dropout(0.25)
        self.dropout2 = nn.Dropout(0.5)
        self.fc1 = nn.Linear(9216, 128)
        self.fc2 = nn.Linear(128, 10)

    def forward(self, x):
        x = self.conv1(x)
        x = F.relu(x)
        x = self.conv2(x)
        x = F.relu(x)
        x = F.max_pool2d(x, 2, 2)
        x = self.dropout1(x)
        x = torch.flatten(x, 1)
        x = self.fc1(x)
        x = F.relu(x)
        x = self.dropout2(x)
        x = self.fc2(x)
        output = F.log_softmax(x, dim=1)
        return output

def train(args, device, model, train_loader, optimizer, epoch):
    model.train()
    n_batch = len(train_loader)
    size_task_dataset = sum(len(data) for (data, target) in train_loader)
    field_size = 1 + int(math.log10(size_task_dataset))
    size_done = 0
    for batch_idx, (data, target) in enumerate(train_loader):
        data, target = data.to(device), target.to(device)
        optimizer.zero_grad()
        output = model(data)
        loss = F.nll_loss(output, target)
        loss.backward()
        optimizer.step()
        batch_idx2 = 1 + batch_idx
        size_done += len(data)
        if batch_idx2 % args.log_interval == 0 or batch_idx2 == n_batch:
            print('{}+{} Train Epoch: {} [{:{}d}/{:.0f} ({:2.0f}%)]'
                    '\tLoss: {:.6f}'.format(
                gethostname(), device, epoch,
                size_done, field_size, size_task_dataset,
                100. * size_done / size_task_dataset, loss.item()), flush=True)
            if args.dry_run:
                break

def test(model, device, test_loader):
    model.eval()
    test_loss = 0
    correct = 0
    with torch.no_grad():
        for data, target in test_loader:
            data, target = data.to(device), target.to(device)
            output = model(data)
            test_loss += F.nll_loss(output, target, reduction='sum').item()  # sum up batch loss
            pred = output.argmax(dim=1, keepdim=True)  # get the index of the max log-probability
            correct += pred.eq(target.view_as(pred)).sum().item()

    test_loss /= len(test_loader.dataset)

    print('\nTest set: Average loss: {:.4f}, Accuracy: {}/{} ({:.0f}%)'.format(
        test_loss, correct, len(test_loader.dataset),
        100. * correct / len(test_loader.dataset)))

def get_int_from_env(env_vars=[], default=1):
    """
    Return first integer from environment variables in list env_vars.
    If no variable set to an integer, return default.
    """
    for env_var in env_vars:
        value = os.getenv(env_var)
        if value is not None:
            try:
                return int(value)
            except ValueError:
                continue
    return default

def main():
    # Training settings
    parser = argparse.ArgumentParser(description='PyTorch MNIST Example')
    parser.add_argument('--ntasks-per-node', default=-1, type=int,
                        help='number of tasks per node for distributed training'
                        '; -1 for number of tasks equal to number of GPUs')
    parser.add_argument('--dist-url', default='127.0.0.1', type=str,
                        help='url used to set up distributed training')
    parser.add_argument('--dist-port', default='55100', type=str,
                        help='url port used to set up distributed training')
    parser.add_argument('--cpus-per-task', default=-1, type=int,
                        help='number of CPUs per task; -1 for all allowed CPUs')
    parser.add_argument('--batch-size', type=int, default=64, metavar='N',
                        help='input batch size for training (default: 64)')
    parser.add_argument('--test-batch-size', type=int, default=1000,
                        metavar='N',
                        help='input batch size for testing (default: 1000)')
    parser.add_argument('--epochs', type=int, default=20, metavar='N',
                        help='number of epochs to train (default: 14)')
    parser.add_argument('--lr', type=float, default=1.0, metavar='LR',
                        help='learning rate (default: 1.0)')
    parser.add_argument('--gamma', type=float, default=0.7, metavar='M',
                        help='Learning rate step gamma (default: 0.7)')
    parser.add_argument('--no-cuda', action='store_true', default=False,
                        help='disables CUDA training')
    parser.add_argument('--no-xpu', action='store_true', default=False,
                        help='disables Intel GPU training')
    parser.add_argument('--no-mps', action='store_true', default=False,
                        help='disables MPS GPU training')
    parser.add_argument('--dry-run', action='store_true', default=False,
                        help='quickly check a single pass')
    parser.add_argument('--seed', type=int, default=1, metavar='S',
                        help='random seed (default: 1)')
    parser.add_argument('--log-interval', type=int, default=30, metavar='N',
                        help='how many batches to wait before logging training status')
    parser.add_argument('--save-model', action='store_true', default=False,
                        help='For Saving the current Model')
    args = parser.parse_args()

    backends = {"cpu": "gloo", "cuda": "nccl", "mps": ""}
    backends["xpu"] = "xccl" if torch.distributed.is_xccl_available() else "ccl"
    for device_type in ["cuda", "xpu", "mps", "cpu"]:
        if getattr(args, f"no_{device_type}", False):
            continue
        try:
            device_module = importlib.import_module(f"torch.{device_type}")
        except ModuleNotFoundError:
            print("Module not found")
            device_module = None
        if getattr(device_module, "is_available", lambda: False)():
            break

    if -1 == args.ntasks_per_node:
        args.ntasks_per_node = device_module.device_count()
    if -1 == args.cpus_per_task and hasattr(os, 'sched_getaffinity'):
        args.cpus_per_task = len(os.sched_getaffinity(0))
        if args.cpus_per_task > 0:
            print(f"Setting cpus_per_task={args.cpus_per_task}")

    if args.cpus_per_task <= 0:
        args.cpus_per_task = 1
        print(f"Setting cpus_per_task={args.cpus_per_task}")
    torch.manual_seed(args.seed)
    
    train_kwargs = {'batch_size': args.batch_size}
    test_kwargs = {'batch_size': args.test_batch_size}
    if device_type in ["cuda", "xpu"]:
        gpu_kwargs = {'num_workers': args.cpus_per_task,
                      'pin_memory': True}
        train_kwargs.update(gpu_kwargs)
        test_kwargs.update(gpu_kwargs)

    transform=transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
        ])
    dataset1 = datasets.MNIST('data',
                              train=True,
                              download=False if os.path.isdir('data') else True,
                              transform=transform)
    dataset2 = datasets.MNIST('data',
                              train=False,
                              download=False,
                              transform=transform)

    world_size = get_int_from_env(
        ["PMI_SIZE", "OMPI_COMM_WORLD_SIZE", "WORLD_SIZE", "SLURM_NTASKS"], 1)
    rank = get_int_from_env(
        ["PMI_RANK", "OMPI_COMM_WORLD_RANK", "RANK", "SLURM_PROCID"], 0)
    local_rank = rank - args.ntasks_per_node * (rank // args.ntasks_per_node)
    current_device = f"{device_type}:{local_rank}"
    backend = backends[device_type] if world_size > 1 else None
    info = (f"host+device: {gethostname()}+{current_device}, "
            f"backend: {backend}, "
            f"world_size: {world_size}, "
            f"rank: {rank}, local_rank: {local_rank}")

    if backend:
        init_method = f"tcp://{args.dist_url}:{args.dist_port}"
        # initialize the process group
        dist.init_process_group(backend=backend, init_method=init_method,
            rank=rank, world_size=world_size, device_id=local_rank)
        info = f"{info} - initialised process group"
        device_module.set_device(current_device)
    print(info)

    train_sampler = torch.utils.data.distributed.DistributedSampler(
            dataset1,
            num_replicas=world_size,
            rank=rank)
    train_loader = torch.utils.data.DataLoader(dataset1,
                                               sampler=train_sampler,
                                               **train_kwargs)

    test_loader = torch.utils.data.DataLoader(dataset2,
                                              **test_kwargs)
    model = Net().to(current_device)
    ddp_model = DDP(model) if backend else model
    optimizer = optim.Adadelta(ddp_model.parameters(), lr=args.lr)

    scheduler = StepLR(optimizer, step_size=1, gamma=args.gamma)
    for epoch in range(1, args.epochs + 1):
        train(args, current_device, ddp_model, train_loader, optimizer, epoch)
        if rank == 0: test(ddp_model, current_device, test_loader)
        scheduler.step()

    if args.save_model and rank == 0:
        torch.save(model.state_dict(), "mnist_cnn.pt")

    if backend:
        dist.destroy_process_group()


if __name__ == '__main__':
    main()
