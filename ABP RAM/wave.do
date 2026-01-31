onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /ABP_RAM_TB/dut/current_state
add wave -noupdate /ABP_RAM_TB/dut/next_state
add wave -noupdate /ABP_RAM_TB/dut/PSEL
add wave -noupdate /ABP_RAM_TB/dut/PENABLE
add wave -noupdate /ABP_RAM_TB/dut/PWRITE
add wave -noupdate /ABP_RAM_TB/dut/PREADY
add wave -noupdate /ABP_RAM_TB/dut/mem
add wave -noupdate /ABP_RAM_TB/dut/ADDR_WD
add wave -noupdate /ABP_RAM_TB/dut/DATA_WD
add wave -noupdate /ABP_RAM_TB/dut/PCLK
add wave -noupdate /ABP_RAM_TB/dut/PRESETn
add wave -noupdate -radix unsigned /ABP_RAM_TB/dut/PADDR
add wave -noupdate -radix unsigned /ABP_RAM_TB/dut/PWDATA
add wave -noupdate -radix unsigned /ABP_RAM_TB/dut/PRDATA
add wave -noupdate /ABP_RAM_TB/dut/PSLVERR
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {395000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 221
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {1193501 ps} {1384553 ps}
