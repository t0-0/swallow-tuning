#!/bin/bash

set -e

start=866
end=866
increment=5000

upload_base_dir=/bb/llm/gaf51275/llama/converted-hf-checkpoint/Swallow-13b-VE-NEFTune/baseline-imitation_2-lr_2e-5-minlr_2e-6-GB_256

for ((i = start; i <= end; i += increment)); do
  upload_dir=$upload_base_dir/iter_$(printf "%07d" $i)

  python tools/upload/upload.py \
    --ckpt-path $upload_dir \
    --repo-name tokyotech-llm/Swallow-13b-VE-NEFTune-v1.0-baseline-imitation_2-lr_2e-5-minlr_2e-6-GB_256-iter$(printf "%07d" $i)
done
