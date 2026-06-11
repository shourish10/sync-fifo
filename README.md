# sync-fifo
synchronous fifo
fifo is a temporarily storage element 
ex : sender sends data at high speed but receiver receives the data slow , in this type of situations fifo (buffer) is used to store the speed data from sender to avoid the data loss
FIFO DEPTH  is calculated in log and the depth should be power of 2
if the both wr_ptr and rd_ptr points to same location it creates the ambiguity wheather the fifo is full or empty to overcome the issue
i used an extra wrap bit to eliminate the ambiguity of fifo full and empty , if both wr_ptr and rd_ptr is same then it results to fifo empty , and if the wr_addr and rd_addr is same but if ptr's bit which is wrap bit is different then it results to fifo full
in fifo we can write when wr_en is 1 and fifo should not be full
from fifo we can read when rd_en is 1 and fifo should not be empty
