from nornir import InitNornir
from nornir_netmiko.tasks import netmiko_send_command, netmiko_send_config
from nornir_utils.plugins.functions import print_result

nr = InitNornir(config_file="config.yaml")


def config_ntp_servers(task):
    """Nornir custom task to configure NTP servers on the devices."""

    # Get the NTP servers from the Nornir host object
    ntp_server = task.host["ntp_server"]
    # Configure the NTP server on the device
    task.run(task=netmiko_send_config, config_commands=[f"ntp server {ntp_server}"])

    # Do a post-check to verify the NTP server was configured
    task.run(task=netmiko_send_command, command_string="show run | inc ntp server")


# Run the task
result = nr.run(task=config_ntp_servers)
# Use print_result helper function to pretty print the result
print_result(result)
