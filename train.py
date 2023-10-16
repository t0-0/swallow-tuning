import logging
from dataclasses import dataclass
from typing import Optional

from datasets import disable_caching, load_dataset, concatenate_datasets
from transformers import AutoTokenizer, TrainingArguments, HfArgumentParser
from trl import DataCollatorForCompletionOnlyLM, SFTTrainer

disable_caching()

logger = logging.getLogger(__name__)


@dataclass
class ExtraArguments:
    data_files: list[str]
    model_name_or_path: str
    tokenizer_name_or_path: Optional[str] = None
    max_seq_length: int = 2048


def formatting_prompts_func(example):
    output_texts = []
    for i in range(len(example["text"])):
        text = example["text"][i].replace("### 応答：", "### 回答：")
        output_texts.append(text)
    return output_texts


def load_datasets(data_files):
    datasets = []
    for data_file in data_files:
        dataset = load_dataset("json", data_files=data_file)
        dataset = dataset["train"]
        dataset = dataset.select_columns("text")
        datasets.append(dataset)
    return concatenate_datasets(datasets)


def main() -> None:
    parser = HfArgumentParser((TrainingArguments, ExtraArguments))
    training_args, extra_args = parser.parse_args_into_dataclasses()

    logger.info(f"Loading tokenizer from {extra_args.tokenizer_name_or_path}")
    tokenizer_name_or_path: str = (
        extra_args.tokenizer_name_or_path or extra_args.model_name_or_path
    )
    tokenizer = AutoTokenizer.from_pretrained(tokenizer_name_or_path)

    logger.info(f"Loading data")

    dataset = load_datasets(extra_args.data_files)

    logger.info("Formatting prompts")
    response_template = "回答："
    collator = DataCollatorForCompletionOnlyLM(response_template, tokenizer=tokenizer)

    logger.info("Setting up trainer")
    trainer = SFTTrainer(
        extra_args.model_name_or_path,
        args=training_args,
        tokenizer=tokenizer,
        train_dataset=dataset,
        formatting_func=formatting_prompts_func,
        data_collator=collator,
        max_seq_length=extra_args.max_seq_length,
    )

    logger.info("Training")
    trainer.train()

    logger.info("Saving model")
    trainer.save_model()


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s %(name)s:%(lineno)d: %(levelname)s: %(message)s",
    )
    main()
