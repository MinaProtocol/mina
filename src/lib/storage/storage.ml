module Checked_data = Checked_data

module type With_checksum_intf = Storage_intf.With_checksum_intf

module Memory : With_checksum_intf with type location = string = Memory

module Disk : With_checksum_intf with type location = string = Disk

module List = List
