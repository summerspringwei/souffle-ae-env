ARG CUDA_VERSION=11.7.1
ARG OS_VERSION=18.04

# FROM nvidia/cuda:${CUDA_VERSION}-base-ubuntu${OS_VERSION}
FROM nvidia/cuda:11.7.1-devel-ubuntu18.04

ENV TZ=Asia/Kolkata \
    DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-c"]

RUN mkdir -p /workspace
WORKDIR /workspace

# Install basic dependencies.
RUN apt-get update && apt-get install \
  -y wget vim git python3 python3-dev python3-setuptools gcc libtinfo-dev zlib1g-dev build-essential cmake libedit-dev libxml2-dev

RUN wget https://github.com/llvm/llvm-project/releases/download/llvmorg-10.0.0/clang+llvm-10.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz \
    && tar -xf clang+llvm-10.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz \
    && rm clang+llvm-10.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz \
    && mv clang+llvm-10.0.0-x86_64-linux-gnu-ubuntu-18.04 clang_10.0.0 \
    && ln -s /clang_10.0.0/bin/clang /usr/bin/clang \
    && ln -s /clang_10.0.0/bin/clang++ /usr/bin/clang++ \
    && ln -s /clang_10.0.0/bin/llvm-config /usr/bin/llvm-config

# Install nsight-compute and nsight-systems
RUN apt-get update -y && \
     DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
         apt-transport-https \
         ca-certificates \
         gnupg \
         wget && \
     rm -rf /var/lib/apt/lists/*
RUN  echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list && \
     wget -qO - https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add - && \
         apt-get update -y && \
     DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
         nsight-compute-2022.4.1 cuda-nsight-systems-11-7 && \
     rm -rf /var/lib/apt/lists/*
ENV PATH=/opt/nvidia/nsight-compute/2022.4.1/:${PATH}


# Install Anaconda
RUN wget https://repo.anaconda.com/archive/Anaconda3-2022.05-Linux-x86_64.sh \
    && bash Anaconda3-2022.05-Linux-x86_64.sh -b -p /workpsace/anaconda3 \
    && rm Anaconda3-2022.05-Linux-x86_64.sh \
    && echo "export PATH=/workpsace/anaconda3/bin:$PATH" >> ~/.bashrc

#  Build and install TVM
RUN git clone --recursive https://github.com/apache/tvm /workspace/tvm \
    && cd /workspace/tvm \
    && git checkout v0.8 \
    && git submodule init \
    && git submodule update \
    && mkdir build \
    && mkdir /workspace/tvm/dbg_build \
    && cp cmake/config.cmake build 
COPY config.cmake /workspace/tvm/build/config.cmake
COPY patch_module_bench_tvm_0.8.patch /workspace/tvm/patch_module_bench_tvm_0.8.patch
RUN cd /workspace/tvm && git apply patch_module_bench_tvm_0.8.patch

# Build release and debug version tvm
RUN cd /workspace/tvm/build && cmake .. \
    && make -j20 \
    && cd /workspace/tvm/dbg_build \
    && cmake -DCMAKE_BUILD_TYPE=Debug .. \
    && make -j20

# Install xgboost for auto_scheduler
RUN /workpsace/anaconda3/bin/pip install xgboost==1.5.0

# Set and modify environment variables here
ENV PYTHONPATH=/workspace/tvm/python:${PYTHONPATH}
ENV LD_LIBRARY_PATH=/workspace/tvm/build:${LD_LIBRARY_PATH}
