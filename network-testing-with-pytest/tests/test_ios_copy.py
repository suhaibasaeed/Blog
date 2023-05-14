from nornir import InitNornir
from nornir_utils.plugins.functions import print_result
from nornir_netmiko import netmiko_send_command
from nornir.core.filter import F
import pytest


def get_ios_device_names():
    """Use 2nd nornir instance to get list of ios devices"""

    # Initalise 2nd nornir instance used for parameterisation
    nr = InitNornir(config_file="config.yaml")

    # Filter for ios devices
    ios_devices = nr.filter(F(groups__contains="ios"))
    # Return list of ios devices
    device_names = ios_devices.inventory.hosts.keys()
    return device_names


# Nornir custom tasks to get output from the devices
def get_ospf_output(task):
    """Run show ip ospf neighbor against device and store in nornir host object"""
    # Use nornir to send command to device
    result = task.run(
        task=netmiko_send_command,
        command_string="show ip ospf neighbor",
        use_textfsm=True,
    )
    # Store result in nornir host object
    task.host["ospf_output"] = result[0].result


def get_bgp_output(task):
    """Run show ip bgp summary against device and store in nornir host object"""
    # Use nornir to send command to device
    result = task.run(
        task=netmiko_send_command,
        command_string="show ip bgp summary",
        use_textfsm=True,
    )
    # Store result in nornir host object
    task.host["bgp_output"] = result[0].result


# Group tests together under a class
class TestIOS:
    # Pytestnr is a fixture defined in conftest.py
    @pytest.fixture(scope="class", autouse=True)
    def setup(self, pytestnr):
        """Fixture to run before tests to get command output from devices"""
        # Filter on ios devices
        ios_devices = pytestnr.filter(F(groups__contains="ios"))

        # Run get_ospf_output and get_bgp_output tasks
        tasks = [get_ospf_output, get_bgp_output]
        for atask in tasks:
            ios_devices.run(task=atask)

    # Use parameterisation to get results back for each ios device
    @pytest.mark.parametrize("device_name", get_ios_device_names())
    def test_ospf_neighbours(self, pytestnr, device_name):
        """Test to check for 2 OSPF neighbours"""

        # Get nornir host object for device
        nr_host = pytestnr.inventory.hosts[device_name]
        # Get OSPF data from nornir host object
        ospf_neighbours = nr_host["ospf_output"]

        # expected_neighbours = nr_host["expected_ospf_neighbours"]
        expected_neighbours = 2
        actual_neighbours = 0

        # Loop through OSPF data and count neighbours
        for neighbour in ospf_neighbours:
            if "FULL" in neighbour["state"]:
                actual_neighbours += 1

        # Assert expected and actual neighbours are the same
        assert (
            expected_neighbours == actual_neighbours
        ), f"Expected {expected_neighbours} OSPF neighbours on {device_name} but got {actual_neighbours} instead"

    @pytest.mark.parametrize("device_name", get_ios_device_names())
    def test_bgp_neighbours(self, pytestnr, device_name):
        """Test to check for 2 BGP neighbours"""

        # Get nornir host object for device
        nr_host = pytestnr.inventory.hosts[device_name]
        # Get BGP data from nornir host object
        bgp_neighbours = nr_host["bgp_output"]

        expected_neighbours = 2
        actual_neighbours = 0

        # Loop through BGP data and count neighbours not in Idle, Active or Connect state
        for neighbour in bgp_neighbours:
            if (
                "Idle" not in neighbour["state_pfxrcd"]
                or "Active" not in neighbour["state_pfxrcd"]
                or "Connect" not in neighbour["state_pfxrcd"]
            ):
                actual_neighbours += 1

        # Assert expected and actual neighbours are the same
        assert (
            expected_neighbours == actual_neighbours
        ), f"Expected {expected_neighbours} BGP neighbours on {device_name} but got {actual_neighbours} instead"
