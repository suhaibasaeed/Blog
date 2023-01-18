from jnpr.junos import Device
from lxml import etree

with Device(host='cr1.cloudnetdev.io', user='x', password='x') as dev:
    
    # Determine RPC for show bgp summary command
    rpc = dev.display_xml_rpc("show bgp summary")

    if type(rpc) is etree._Element:
        # Set XML attribute to get text format
        rpc.attrib['format']='text'
        # Execute RPC and print output
        result = dev.rpc(rpc)
        print(result.text)

    else:
        print(f"XML RPC for command not available: {rpc}")