#!/bin/bash
#$ -l rt_AF=2
#$ -l h_rt=2:00:00:00
#$ -j y
#$ -o outputs/swallow-7b/instruction/
#$ -cwd

# module load
source /etc/profile.d/modules.sh
module load cuda/11.8/11.8.0
module load cudnn/8.9/8.9.2
module load nccl/2.16/2.16.2-1
module load hpcx/2.12

# python virtualenv
source .env/bin/activate

# distributed settings
export MASTER_ADDR=$(/usr/sbin/ip a show dev bond0 | grep 'inet ' | awk '{ print $2 }' | cut -d "/" -f 1)
export MASTER_PORT=$((10000 + ($JOB_ID % 50000)))

echo "MASTER_ADDR=${MASTER_ADDR}"

# hostfile

if [[ "$SGE_RESOURCE_TYPE" == "rt_F" ]]; then
  export NUM_GPU_PER_NODE=4
  NODE_TYPE="v100"
elif [[ "$SGE_RESOURCE_TYPE" == "rt_AF" ]]; then
  export NUM_GPU_PER_NODE=8
  NODE_TYPE="a100"
else
  echo "Unrecognized SGE_RESOURCE_TYPE: $SGE_RESOURCE_TYPE"
fi

NUM_NODES=$NHOSTS
NUM_GPUS=$((${NUM_NODES} * ${NUM_GPU_PER_NODE}))

mkdir -p ./hostfile

HOSTFILE_NAME=./hostfile/hostfile_${JOB_ID}
while read -r line; do
  echo "${line} slots=${NUM_GPU_PER_NODE}"
done <"$SGE_JOB_HOSTLIST" >"$HOSTFILE_NAME"

# training config
MICRO_BATCH_SIZE=1
GLOBAL_BATCH_SIZE=64
GRADIENT_ACCUmULATION_STEPS=$(($GLOBAL_BATCH_SIZE / $MICRO_BATCH_SIZE / $NUM_GPUS))

if [[ $GRADIENT_ACCUmULATION_STEPS -lt 1 ]]; then
  echo "Global batch size is too small for the number of GPUs"
  exit 1
fi

LR=1e-4
MIN_LR=3.3e-6
LR_WARMUP_STEPS=1000
WEIGHT_DECAY=0.1
GRAD_CLIP=1

EPOCH=2
SEQ_LENGTH=4096

# model config
MODEL_CHECKPOINT_PATH=""
MODEL_CHECKPOINT_SAVE_PATH=""
TOKENIZER_PATH=""

# run
mpirun -np $NUM_GPUS \
  --npernode $NUM_GPU_PER_NODE \
  -hostfile $HOSTFILE_NAME \
  -x MASTER_ADDR=$MASTER_ADDR \
  -x MASTER_PORT=$MASTER_PORT \
  -x CUDA_DEVICE_MAX_CONNECTIONS=1 \
  -bind-to none -map-by slot \
  -x PATH \
  python train.py \
    --model_name_or_path $MODEL_CHECKPOINT_PATH \
    --tokenizer_name_or_path $TOKENIZER_PATH \
    --num_train_epochs $EPOCH \
    --per_device_train_batch_size $MICRO_BATCH_SIZE \
    --gradient_accumulation_steps $GRADIENT_ACCUmULATION_STEPS \
    --learning_rate $LR \
    --warmup_ratio 0.1 \
    --lr_scheduler cosine \
    --bf16 \
    --max_seq_length $SEQ_LENGTH \
    --gradient_checkpointing \
    --save_steps 500 \
    --save_total_limit 2 \
    --logging_steps 1 \
    --report_to wandb \
    --log_on_each_node False \
    --deepspeed ${config_json} \
    --output_dir $MODEL_CHECKPOINT_SAVE_PATH \
    --data_files