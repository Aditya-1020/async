set WR_PERIOD 10.0
set RD_PERIOD 20.0

create_clock [get_ports wr_clk] -name wr_clk -period $WR_PERIOD
create_clock [get_ports rd_clk] -name rd_clk -period $RD_PERIOD

set_clock_groups -name afifo_async_group -asynchronous -group [get_clocks wr_clk] -group [get_clocks rd_clk]

