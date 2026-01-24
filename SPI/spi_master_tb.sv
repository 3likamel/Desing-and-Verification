//======================================================
// SPI INTERFACE
//======================================================
interface spi_master_if;
    logic        rst_n;
    logic [7:0]  data_in;
    logic        start;
    logic        clk;
    logic        sclk;
    logic        mosi;
    logic        cs_n;

    property no_clk_when_cs_high;
         @(posedge sclk)
         cs_n == 0;
     endproperty

    assert_no_clk: assert property(no_clk_when_cs_high)
    else $fatal("SPI PROTOCOL: SCLK toggled while CS is high");
endinterface

//======================================================
// TRANSACTION
//======================================================
class transaction;
    rand logic [7:0] data;

    function transaction copy();
        transaction c = new();
        c.data = this.data;
        return c;
    endfunction

    function void display(string tag);
        $display("[%s] DATA = %0d", tag, data);
    endfunction

endclass

//======================================================
// GENERATOR
//======================================================
class generator;
    transaction tr;
    mailbox #(transaction) gen2drv;
    mailbox #(transaction) gen2sco;
    event done;
    event sconext;

    function new(mailbox #(transaction) g2d,
                 mailbox #(transaction) g2s);
        gen2drv = g2d;
        gen2sco = g2s;
        tr = new();
    endfunction

    task run();
        $display( " =============================== " );
        repeat (10) begin
            $display( " =============================== " );
            assert(tr.randomize()) else $fatal("Randomization failed");
            tr.display("GEN");
            gen2drv.put(tr.copy());
            gen2sco.put(tr.copy());
            $display("[%0t] GENERATOR sent transaction", $time);
            @(sconext);
        end
        -> done;
    endtask
endclass

//======================================================
// DRIVER
//======================================================
class driver;
    transaction tr;
    mailbox #(transaction) gen2drv;
    virtual spi_master_if vif;

    function new(mailbox #(transaction) g2d);
        gen2drv = g2d;
        tr = new();
    endfunction

    task reset();
        vif.rst_n   <= 0;
        vif.start   <= 0;
        vif.data_in <= 0;
        vif.cs_n    <= 1;
        vif.sclk    <= 0;
        vif.mosi    <= 0;
        repeat (5) @(posedge vif.clk);
        vif.rst_n <= 1;
        $display("[%0t] RESET DONE", $time);
    endtask

    task run();
        forever begin
            gen2drv.get(tr);
            $display("[%0t] DRIVER got transaction...", $time);
            tr.display("DRV");

            vif.data_in <= tr.data;
            vif.start   <= 1;

            repeat(3)@(posedge vif.clk);
            vif.start <= 0;
            $display("[%0t] DRIVER started transaction with data=%0d", $time, tr.data);
            // wait until SPI transaction finishes
            wait (vif.cs_n == 1);
        end
    endtask
endclass

//======================================================
// MONITOR
//======================================================
class monitor;
    transaction tr;
    mailbox #(bit [7:0]) mon2sco;
    virtual spi_master_if vif;

    function new(mailbox #(bit [7:0]) mon2sco);
        this.mon2sco = mon2sco;
        tr = new();
    endfunction

    bit [7:0] captured_data;

    task run();
        forever begin
            @(negedge vif.cs_n);
             for (int i = 0; i < 8; i++) begin
                @(posedge vif.sclk);
                captured_data[7-i] = vif.mosi;
            end
            $display("[%0t] MONITOR captured data: %0d", $time, captured_data);
            mon2sco.put(captured_data);
        end
    endtask
endclass

//======================================================
// SCOREBOARD
//======================================================
class scoreboard;
    mailbox #(transaction) gen2sco;
    mailbox #(bit [7:0]) mon2sco;
    transaction tg, tm;
    event sconext;

    bit [7:0] c;
    function new(mailbox #(transaction) g2s,
                 mailbox #(bit [7:0]) m2s);
        gen2sco = g2s;
        mon2sco = m2s;
        tg = new();
    endfunction

    task run();
        forever begin
            gen2sco.get(tg);
            mon2sco.get(c);
            if (tg.data !== c) begin
                $error("[%0t] MISMATCH GEN=%0d MON=%0d",
                        $time, tg.data, c);
            end
            else begin
                $display("[%0t] MATCH DATA=%0d",
                          $time, tg.data);
            end
            $display( " =============================== " );
            -> sconext;
        end
    endtask
endclass

//======================================================
// ENVIRONMENT
//======================================================
class environment;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard sco;

    mailbox #(transaction) g2d, g2s;
    mailbox #(bit [7:0]) m2s;
    virtual spi_master_if vif;

    event sconext;

    function new(virtual spi_master_if vif);
        this.vif = vif;

        g2d = new();
        g2s = new();
        m2s = new();

        gen = new(g2d, g2s);
        drv = new(g2d);
        mon = new(m2s);
        sco = new(g2s, m2s);
        gen.sconext = this.sconext;
        sco.sconext = this.sconext;
        drv.vif = vif;
        mon.vif = vif;
    endfunction

    task run();
        drv.reset();

        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_none
        $display("[%0t] ENV waiting for GEN done...", $time);
        @(gen.done.triggered);
        //#2000;
        $finish;
    endtask
endclass

//======================================================
// TOP TESTBENCH
//======================================================
module spi_master_tb;

    spi_master_if vif();
    environment env;

    // CLOCK
    initial begin
        vif.clk = 0;
        forever #10 vif.clk = ~vif.clk;
    end

    // DUMP
    initial begin
        $dumpfile("spi_master_tb.vcd");
        $dumpvars;
    end

    // ENV
    initial begin
        env = new(vif);
        env.run();
    end

    // DUT
    spi_master dut (
        .clk     (vif.clk),
        .rst_n   (vif.rst_n),
        .data_in (vif.data_in),
        .start   (vif.start),
        .sclk    (vif.sclk),
        .mosi    (vif.mosi),
        .cs_n    (vif.cs_n)
    );

endmodule
