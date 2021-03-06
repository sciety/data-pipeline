import logging

import pytest


@pytest.fixture(scope='session', autouse=True)
def setup_logging():
    logging.basicConfig(level='INFO')
    for name in ['tests', 'sciety_data_pipeline']:
        logging.getLogger(name).setLevel('DEBUG')
