
# Build docker image
docker build -t tvm-0.8:latest -f ./tvm_0.8.Dockerfile .

# Run docker image
docker run --gpus all -it -v /home/xiachunwei/Software/tensor-compiler:/workspace/tensor-compiler tvm-0.8:latest /bin/bash
