# async_fifo.sdc
# Initial target: 100 MHz write, 100 MHz read

create_clock [get_ports wr_clk] -name wr_clk -period 10.0
create_clock [get_ports rd_clk] -name rd_clk -period 10.0

set_clock_groups \
    -name afifo_async_group \
    -asynchronous \
    -group [get_clocks wr_clk] \
    -group [get_clocks rd_clk]

# IMPORTANT:
# Replace these patterns after first synthesis by inspecting the synthesized netlist or GUI.
# Use the FIRST synchronizer stage that captures the gray pointer in the destination domain.

# Example: write pointer synchronized into read clock domain
set wr2rd_sync_d [get_pins -hierarchical *wr_ptr_gray_sync*/*/D]
set wr2rd_sync_q [get_pins -hierarchical *wr_ptr_gray_sync*/*/Q]

if { [llength $wr2rd_sync_d] > 0 && [llength $wr2rd_sync_q] > 0 } {
    set_max_delay -datapath_only 8.0 \
        -from $wr2rd_sync_d \
        -to $wr2rd_sync_q
}

# Example: read pointer synchronized into write clock domain
set rd2wr_sync_d [get_pins -hierarchical *rd_ptr_gray_sync*/*/D]
set rd2wr_sync_q [get_pins -hierarchical *rd_ptr_gray_sync*/*/Q]

if { [llength $rd2wr_sync_d] > 0 && [llength $rd2wr_sync_q] > 0 } {
    set_max_delay -datapath_only 8.0 \
        -from $rd2wr_sync_d \
        -to $rd2wr_sync_q
}

# Optional: only keep this if your OpenSTA/OpenROAD build supports it cleanly
if { [llength $wr2rd_sync_d] > 0 && [llength $wr2rd_sync_q] > 0 } {
    set_bus_skew 0.5 \
        -from $wr2rd_sync_d \
        -to $wr2rd_sync_q
}

if { [llength $rd2wr_sync_d] > 0 && [llength $rd2wr_sync_q] > 0 } {
    set_bus_skew 0.5 \
        -from $rd2wr_sync_d \
        -to $rd2wr_sync_q
}