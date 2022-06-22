import argparse
import logging
import json
import re
from pathlib import Path
from typing import Optional, Sequence


LOGGER = logging.getLogger(__name__)


def parse_args(argv: Optional[Sequence[str]]) -> argparse.Namespace:
    parser = argparse.ArgumentParser('Convert listCreated script to JSON')
    parser.add_argument('--js-script')
    parser.add_argument('--output-json-file')
    return parser.parse_args(argv)


def iter_parse_list_created_script_content_to_json(js_script_content: str) -> Sequence[dict]:
    for m in re.finditer(
        (
            r"listCreated\("
            r"[^']+'([^']+)'"
            r"[^']+'([^']+)'"
            r"[^']+'([^']+)'"
            r"[^']+'([^']+)'"
            r"[^']+'([^']+)'"
        ),
        js_script_content
    ):
        LOGGER.debug('m: %r', m)
        LOGGER.debug('m: %r', m.group(1))
        yield {
            'listId': m.group(1),
            'name': m.group(2),
            'description': m.group(3),
            'ownerId': m.group(4),
            'creationDate': m.group(5)
        }


def main(argv: Optional[Sequence[str]] = None):
    args = parse_args(argv)
    LOGGER.info('args: %r', args)
    input_file = Path(args.js_script)
    output_file = Path(args.output_json_file)
    json_list = list(iter_parse_list_created_script_content_to_json(input_file.read_text()))
    output_file.write_text(json.dumps(json_list, indent=2))


if __name__ == '__main__':
    logging.basicConfig(level='INFO')
    main()
