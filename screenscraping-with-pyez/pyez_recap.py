from jnpr.junos import Device
from lxml import etree

# Connect to the device using context manager
with Device(host="cr1.cloudnetdev.io", user="x", password="x") as dev:
    
    # Execute show version rpc
    cr = dev.rpc.get_software_information()
    # Print XML output
    print(etree.tostring(cr, encoding="unicode"))