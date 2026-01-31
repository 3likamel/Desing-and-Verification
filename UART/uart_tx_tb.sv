
parameter count = 5; // number of transactions to be generated
parameter Data_WD = 8; // data width

interface UART_TX_if #(parameter Data_WD = 8);
    
	logic   [Data_WD-1 : 0]	P_DATA;
	logic   				Data_Valid;
	logic   				PAR_EN;
	logic   				PAR_TYP;
	logic   				start_bit;
	logic   				stop_bit;
	logic   				CLK,RST;
	logic   				TX_OUT;
	logic   				busy;
    
endinterface

// width if parity enabled is Data_WD + 1 else Data_WD for the storage so we should use queues or dynamic arrays

class transaction;
    rand bit [Data_WD-1 : 0] P_DATA;
    rand bit PAR_EN;
    rand bit PAR_TYP;
    

     // storing outbut data
    bit                   start_o;
    bit                   stop_o;
    bit                   par_o;
    bit   [Data_WD-1 : 0] data_o;

    function transaction copy();
        copy = new();
        copy.P_DATA = this.P_DATA;
        copy.PAR_EN = this.PAR_EN;
        copy.PAR_TYP = this.PAR_TYP;
        copy.start_o = this.start_o;
        copy.stop_o  = this.stop_o;
        copy.par_o   = this.par_o;
        copy.data_o  = this.data_o;
    endfunction

    function void display(string tag);
        $display("[%0s] [%0t] P_DATA = %0d, PAR_EN = %0b, PAR_TYP = %0b, start_o = %0b, data_o = %0b, par_o = %0b, stop_o =  %0b",tag, $time, P_DATA, PAR_EN, PAR_TYP,start_o,data_o,par_o,start_o);
    endfunction

endclass
class generator;

    transaction tr;
    mailbox  #(transaction) gen2drv, gen2sco;
    event sconext;
    event done;

    function new(mailbox  #(transaction) gen2drv, mailbox  #(transaction) gen2sco);
        this.gen2drv = gen2drv;
        this.gen2sco = gen2sco;
        tr = new();
    endfunction

    task run();
        repeat (count) begin
            $display("=============================================");
            assert(tr.randomize()) else $fatal("Randomization failed");
            tr.display("GEN");
            gen2drv.put(tr.copy());
            gen2sco.put(tr.copy());
            @(sconext);
        end
        ->done;
    endtask

endclass

class driver;

    transaction tr;
    virtual UART_TX_if uart_if;
    mailbox  #(transaction) gen2drv;
    
    function new(mailbox  #(transaction) gen2drv);
        this.gen2drv = gen2drv;
        tr = new();
    endfunction

    task reset();
        uart_if.RST <= 1'b1;
        @(negedge uart_if.CLK);
        uart_if.RST <= 1'b0;
        uart_if.start_bit <= 1'b0;
        uart_if.stop_bit  <= 1'b1;
        uart_if.P_DATA <= '0;
        uart_if.PAR_EN <= 1'b0;
        uart_if.PAR_TYP <= 1'b0;
        uart_if.Data_Valid <= 1'b0;
        repeat (3) @(posedge uart_if.CLK);
        uart_if.RST <= 1'b1;
    endtask


    task run();
        forever begin
            gen2drv.get(tr);
            tr.display("DRV");
            // drive the interface signals
            @(posedge uart_if.CLK);
            uart_if.P_DATA     <= tr.P_DATA;
            uart_if.PAR_EN     <= tr.PAR_EN;
            uart_if.PAR_TYP    <= tr.PAR_TYP;
            uart_if.Data_Valid <= 1'b1;
            @(posedge uart_if.CLK);
            uart_if.Data_Valid =  1'b0;
            wait (uart_if.busy == 1'b0);
        end
    endtask
endclass    

class monitor;

    transaction tr;
    virtual UART_TX_if uart_if;
    mailbox  #(transaction) mon2sco;
    function new(mailbox  #(transaction) mon2sco);
        this.mon2sco = mon2sco;
        tr = new();
    endfunction

    task run();
        forever begin
            @(negedge uart_if.Data_Valid);
            tr.P_DATA	= uart_if.P_DATA; 
            tr.PAR_EN   = uart_if.PAR_EN;
            tr.PAR_TYP  = uart_if.PAR_TYP;
            tr.start_o  = uart_if.start_bit;
            for( int i = 0; i < Data_WD; i++) begin
                @(posedge uart_if.CLK);
                @(negedge uart_if.CLK);
                tr.data_o [i] = uart_if.TX_OUT;
            end
            $display("[MON] [%0t] Captured data = %0d",$time, tr.data_o);
            if (tr.PAR_EN) begin
                @(posedge uart_if.CLK);
                @(negedge uart_if.CLK);
                tr.par_o = uart_if.TX_OUT;
                @(posedge uart_if.CLK);
                @(negedge uart_if.CLK);
                tr.stop_o = uart_if.TX_OUT;
            end else begin
                @(posedge uart_if.CLK);
                @(negedge uart_if.CLK);
                tr.par_o  = 1'b0; // no parity
                tr.stop_o = uart_if.TX_OUT;
            end
            mon2sco.put(tr);
        end
    endtask
endclass

class scoreboard;

    transaction observed_tr;
    transaction expected_tr;
    mailbox  #(transaction) gen2sco;
    mailbox  #(transaction) mon2sco;
    virtual UART_TX_if uart_if;
    event sconext;
    bit parity;
    function new(mailbox  #(transaction) gen2sco, mailbox  #(transaction) mon2sco);
        this.gen2sco = gen2sco;
        this.mon2sco = mon2sco;
    endfunction
    function void correct(string tag);
        $display("[SCO] [%0t] %0s bit is CORRECT",$time,tag);
    endfunction



    task run();
        forever begin

            expected_tr = new();
            observed_tr = new();
            gen2sco.get(expected_tr);
            mon2sco.get(observed_tr);
            expected_tr.display("SCO-EXP");
            observed_tr.display("SCO-OBS");
            
            parity = ^expected_tr.P_DATA; // calculate parity
            assert(observed_tr.start_o == 1'b0) else $error("[SCO] Start bit is WRONG"); // start bit check
            this.correct("Sart");
            assert(observed_tr.stop_o  == 1'b1) else $error("[SCO] Stop bit is WRONG");  // stop bit check
            this.correct("Stop");



            if (expected_tr.PAR_EN) begin
                if (observed_tr.data_o == expected_tr.P_DATA) begin
                    $display("[SCO] Data bits are correct");
                end else begin
                    $error("[SCO] Data bits are WRONG");
                end
                if (expected_tr.PAR_TYP) begin
                    if (parity == 1) begin
                        assert(observed_tr.par_o == 0) else $error("[SCO] Parity bit is WRONG"); // odd parity
                        this.correct("Parity");
                    end else begin
                        assert(observed_tr.par_o == 1) else $error("[SCO] Parity bit is WRONG"); // odd parity
                        this.correct("Parity");
                    end
                end else begin
                    if (parity == 1) begin
                        assert(observed_tr.par_o == 1) else $error("[SCO] Parity bit is WRONG"); // even parity
                        this.correct("Parity");
                    end else begin
                        assert(observed_tr.par_o == 0) else $error("[SCO] Parity bit is WRONG"); // even parity
                        this.correct("Parity");
                    end
                end
            end else begin
                if (observed_tr.data_o == expected_tr.P_DATA) begin
                    $display("[SCO] Data bits are correct");
                end else begin
                    $error("[SCO] Data bits are WRONG");
                end
            end
            $display("[SCO] Transaction Verified Successfully");
            $display("=============================================");
            -> sconext;
        end
    endtask
endclass

class environment;

    virtual UART_TX_if uart_if;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    mailbox  #(transaction) gen2drv, gen2sco, mon2sco;
    event sconext;
    event check;
    int total_Width;

    function new(virtual UART_TX_if uart_if);
        this.uart_if = uart_if;
        gen2drv = new();
        gen2sco = new();
        mon2sco = new();
        gen = new(gen2drv, gen2sco);
        drv = new(gen2drv);
        mon = new(mon2sco);
        sco = new (gen2sco, mon2sco);
        drv.uart_if = uart_if;
        mon.uart_if = uart_if;
        sco.sconext = sconext;
        gen.sconext = sconext;
    endfunction

    task pre_test;
        $dumpfile("uart_tx_tb.vcd");
        $dumpvars;
        drv.reset();
        $display("[ENV] Pre-test completed [RESET DONE]");
    endtask

    task test;
         fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
         join_none
        @(gen.done);
    //    #2000;
        $finish;
    endtask

    task post_test;
        $display("[ENV] test completed");
    endtask

    task run();
        pre_test();
        test();
        post_test();
    endtask

endclass


module uart_tx_tb;
 
   // Instantiate the interface
    UART_TX_if uart_if();
    environment env;
   // assign Data_WD = (uart_if.PAR_EN) ? 9 : 8;
    
    // Instantiate the DUT
    UART_TX #(Data_WD) dut (
        .P_DATA     (uart_if.P_DATA),
        .Data_Valid (uart_if.Data_Valid),
        .PAR_EN     (uart_if.PAR_EN),
        .PAR_TYP    (uart_if.PAR_TYP),
        .start_bit  (uart_if.start_bit),
        .stop_bit   (uart_if.stop_bit),
        .CLK        (uart_if.CLK),
        .RST        (uart_if.RST),
        .TX_OUT     (uart_if.TX_OUT),
        .busy       (uart_if.busy)
    );

    // Clock generation
    initial begin
        uart_if.CLK = 0;
        forever #5 uart_if.CLK = ~uart_if.CLK; // 10 time units clock period
    end
    // Testbench run
    initial begin
        env = new(uart_if);
        env.run();
    end
endmodule