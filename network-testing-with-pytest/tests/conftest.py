import pytest
from nornir import InitNornir

# Use fixture for entire session - all tests will use this automatically
@pytest.fixture(scope="session", autouse=True)
def pytestnr():
    # Initalise nornir
    pytestnr = InitNornir(config_file="config.yaml")
    # Return nr object
    yield pytestnr
    # What to do after test - i.e. close connections
    pytestnr.close_connections()
