# Author: Federica Sarnataro
# Description: This file defines the CSR peripheral (Simply-V control and status registers)

from general.addr_range import Addr_Ranges
from .peripheral import Peripheral


class CSR(Peripheral):
	# Given the MMIO registers layout (hw/xilinx/rtl/simplyv_csr.sv):
	# - COMMAND   : 0x00
	# - STATUS    : 0x04
	# - BOOT_ADDR : 0x08
	# - PTR_IN    : 0x0C
	# - PTR_OUT   : 0x10
	# - RT_STATUS : 0x14
	min_addr_space = 0x18

	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
		self.HAL_DRIVER = True
