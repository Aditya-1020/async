DATA_WIDTH = 16
ADDR_WIDTH = 6
DEPTH = 1 << ADDR_WIDTH # 64

word_size = DATA_WIDTH
num_words = DEPTH

num_rw_ports = 1
num_r_ports = 1

num_spare_cols = 0
num_spare_rows = 0

tech_name = "sky130"
process_corners = ["TT"]
supply_voltages = [1.8]
temperatures = [25]

route_supplies = True
check_lvsdrc = True
output_name = "fifo_sram_16x64_pdp"
output_path = "build"