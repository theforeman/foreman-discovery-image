# PCI Card Enumeration Script

# This is what lspci output looks like:
# [empty line]
# Slot:	01:00.0
# Class:	RAID bus controller
# Vendor:	LSI Logic / Symbios Logic
# Device:	MegaRAID SAS-3 3108 [Invader]
# SVendor:	IBM
# SDevice:	Device 0454
# PhySlot:	4
# Rev:	02
# NUMANode:	0
# [empty line]
# [another section]

# Expected output:
# pci_device_0 => NetXtreme BCM5719 Gigabit Ethernet PCIe
# pci_device_1 => SFC9220 10/40G Ethernet Controller
# pci_device_2 => SFC9220 10/40G Ethernet Controller
# pci_device_4 => MegaRAID SAS-3 3108 [Invader]

require 'facter'

# Read lspci
begin
    lspci_output = %x{lspci -mm -v}
rescue => e
    warn "Invocation of lspci failed: #{e}"
    lspci_output = ''
end

# Filter relevant data
all_devices = {}
current_element = {}
lspci_output.each_line do |line|
    line.chomp!
    # Newline triggers evaluation of values read earlier
    if line == '' then
        # Only store PCI devices that report a physical PCI slot
        if current_element.has_key?('physlot') then
            all_devices[current_element['physlot']] = current_element['device']
        end

        # Clear values, process next PCI device
        current_element = {}
        next
    end

    key, value = line.split(/:\t/, 2)
    key.downcase!

    current_element[key] = value
end

# Convert stored data to facts:
all_devices.each do |slot, model|
  Facter.add("pci_device_#{slot}") do
    setcode { model.chomp }
  end
end
