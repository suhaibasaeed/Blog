from jnpr.junos import Device
from lxml import etree

with Device(host='cr1.cloudnetdev.io', user='x', password='x') as dev:    
    
    output = dev.cli("show interfaces terse")

    print(output)