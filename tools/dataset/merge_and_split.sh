#!/bin/bash

INPUT_DIR=/gs/bs/tga-bayes-crest/takumi/datasets/all
OUTPUT_DIR=/gs/bs/tga-bayes-crest/takumi/datasets/baseline

mkdir -p $OUTPUT_DIR

FILES_TO_MERGE=(
  "databricks-dolly-15k-en.jsonl"
  "databricks-dolly-15k-ja.jsonl"
  "oasst1-21k-en.jsonl"
  "oasst1-21k-ja.jsonl"
)

# reset merged.jsonl
rm -f "$OUTPUT_DIR/merged.jsonl"

# merge files
for FILE in "${FILES_TO_MERGE[@]}"; do
  cat "$INPUT_DIR/$FILE" >> "$OUTPUT_DIR/merged.jsonl"
done

echo "Merged dataset is saved at $OUTPUT_DIR/merged.jsonl"

# swich virtual env
# source .env/bin/activate

python tools/dataset/shuffle_and_split.py \
  --input $OUTPUT_DIR/merged.jsonl \
  --output $OUTPUT_DIR
