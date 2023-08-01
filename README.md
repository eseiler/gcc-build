# GCC build script

# First-time Setup

1. Checkout GCC source in a directory of your choice:
```bash
git clone https://github.com/gcc-mirror/gcc.git
```

2. Set `GITDIR` in `gcc-build.sh`:
https://github.com/eseiler/gcc-build/blob/c790c7456e1cb1ae8191056a82f235a17b6d58e4/gcc-build.sh#L21

3. Set `BINARYDIR` in `gcc-build.sh`:
https://github.com/eseiler/gcc-build/blob/c790c7456e1cb1ae8191056a82f235a17b6d58e4/gcc-build.sh#L23

# Running

```
Usage: gcc-build.sh <version>
For example, gcc-build.sh 13.2
```

In case the specified version does not exist, the user is prompted to confirm using the master branch.
This is useful for building the current master, e.g.
```bash
gcc-build.sh 14.0
```
At the time of writing, GCC 14.0 is not released and refers to the current master.

# Output

The script will create a temporary `-build` directory and an install directory, where GCC is installed.
These directories will be sibling directories of the GCC checkout.
```bash
|-- gcc
|-- gcc-13
|-- gcc-13-build # Temporary, will be removed after successful run.
```

Wrappers are created for GCC compiler calls (`g++`, `cpp`, `gcc`, `c++`) within `BINARYDIR`.
For all other binaries, a symlink will be created.

Subsequent calls with a new minor version, e.g., running the script for `13.2`, when `13.1` is already installed,
will overwrite the installation. This preserves the linkage of, for example, `libstdc++`.

# Limitations

## Root access

If the binaries should be installed into, e.g., `BINARYDIR=/usr/local/bin`, root access is needed.
The script then needs to be run from a root shell:
```bash
sudo bash
gcc-build.sh 13.2
```
