#
# $ FACTERLIB=/usr/share/fdi/facts tfm-ruby /opt/theforeman/tfm/root/usr/bin/facter
#

require 'facter'

class PartedInfo

  attr_accessor :units, :size, :transport_type, :logical_sector_size, :physical_sector_size, :partition_table_type, :model_name, :flags

  def initialize(disk)
    parted_lines = `parted --machine --script /dev/#{disk} print 2>/dev/null`.split("\n", -1)
    # https://git.savannah.gnu.org/cgit/parted.git/tree/parted/parted.c?h=v3.5#n1116
    if parted_lines.length >= 2 &&
      /^(?<units>CHS|CYL|BYT);$/ =~ parted_lines[0] &&
      /^\/.+?:(?<size>.+?):(?<transport_type>.+?):(?<logical_sector_size>\d+):(?<physical_sector_size>\d+):(?<partition_table_type>.+?):(?<model_name>.+?):(?<flags>.*?);$/ =~ parted_lines[1]
      @units = units
      @size = size
      @transport_type = transport_type
      @logical_sector_size = logical_sector_size.to_i
      @physical_sector_size = physical_sector_size.to_i
      @partition_table_type = partition_table_type
      @model_name = model_name
      @flags = flags.length > 0 ? flags : nil
    end
  end
end

Facter.add(:disks_partition_table) do
  confine kernel: "Linux"

  confine :disks do |value|
    value != nil
  end

  confine :identity do |identity|
    identity['uid'] === 0
  end

  setcode do
    hash = {}
    Facter.value(:disks).each_key do |disk|
      parted_info = PartedInfo.new(disk)
      hash[disk] = {
        :units => parted_info.units,
        :size => parted_info.size,
        :transport_type => parted_info.transport_type,
        :logical_sector_size => parted_info.logical_sector_size,
        :physical_sector_size => parted_info.physical_sector_size,
        :partition_table_type => parted_info.partition_table_type,
        :model_name => parted_info.model_name,
        :flags => parted_info.flags
      }
    end
    hash
  end
end
