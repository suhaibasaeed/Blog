from jnpr.junos import Device
from jnpr.junos.utils.start_shell import StartShell

# Connect to the device using context manager
with Device(host="cr1.cloudnetdev.io", user="x", password="x") as dev:

	# Create shell connection
    with StartShell(dev) as ss:
    	# Send CLI command to compress logs into .tgz file
    	ss.run('cli -c "file archive compress source /var/log/* destination /var/tmp/re0.tgz"')
        ver = ss.run('cli -c "show version"')
        print(ver)