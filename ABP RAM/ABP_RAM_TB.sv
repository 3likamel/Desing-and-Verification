`timescale 1ns/1ps

parameter test_cnt = 20;
parameter DATA_WD = 32; 
parameter ADDR_WD = 8;  // the real is 32 bit but for test we use 8 bit


interface ABP_RAM_IF ();
	logic                   PCLK;
    logic                   PRESETn;
    logic                   PSEL;
    logic                   PENABLE;
    logic                   PWRITE;
    logic   [ADDR_WD-1:0]   PADDR;
    logic   [DATA_WD-1:0]   PWDATA;
    logic   [DATA_WD-1:0]   PRDATA;
    logic                   PREADY;
    logic                   PSLVERR;

endinterface : ABP_RAM_IF

class transaction;

    bit                   PSEL;
    bit                        PENABLE;
    randc bit                   PWRITE;
    rand bit   [ADDR_WD-1:0]   PADDR;
    rand bit   [DATA_WD-1:0]   PWDATA;
    bit        [DATA_WD-1:0]   PRDATA;
    bit                        PREADY;
    bit                        PSLVERR;

    function transaction copy();
        copy = new();
        copy =  this;
    endfunction : copy

    function void display(string tag);
        $display("[%0t] [%0s] PWRITE: %0b, PADDR: %0d, PWDATA: %0d, PRDATA: %0d, PSLVERR: %0b",
                 $time, tag, PWRITE, PADDR, PWDATA, PRDATA, PSLVERR);
    endfunction

endclass : transaction

class generator;

    transaction tr;
    mailbox #(transaction) g2d, g2s;

    event sconxt, done;

    function new(mailbox #(transaction) g2d, mailbox #(transaction) g2s);
        this.g2d = g2d;
        this.g2s = g2s;
        tr = new();
    endfunction

    task run();
        repeat (test_cnt) begin
            $display(" =============================== ");
            tr.randomize();
            g2d.put(tr.copy());
            g2s.put(tr.copy());
            tr.display("GEN");
            @(sconxt);
        end
        -> done;
    endtask

endclass


class driver;

    transaction tr;
    virtual ABP_RAM_IF vif;
    mailbox #(transaction) g2d;

    function new(virtual ABP_RAM_IF vif, mailbox #(transaction) g2d);
        this.vif = vif;
        this.g2d = g2d;
        tr = new();
    endfunction

    task run();
        
        forever begin

            g2d.get(tr);
            tr.display("DRV");

            // IDLE
            @(posedge vif.PCLK);
            vif.PSEL    <= 0;
            vif.PENABLE <= 0;
            // SETIP
            @(posedge vif.PCLK);
            vif.PSEL    <= 1;
            vif.PENABLE <= 0;
            vif.PWRITE  <= tr.PWRITE;
            vif.PADDR   <= tr.PADDR;
            vif.PWDATA  <= tr.PWDATA;
            
            // ACCESS
            @(posedge vif.PCLK);
            vif.PSEL    <= 1;
            vif.PENABLE <= 1;
            // reutn IDLE
            @(posedge vif.PCLK);
            vif.PSEL    <= 0;
            vif.PENABLE <= 0;
            @(!vif.PREADY);

        end
    endtask
endclass


class monitor;

    transaction tr;
    virtual ABP_RAM_IF vif;
    mailbox #(transaction) m2s;

    function new(virtual ABP_RAM_IF vif, mailbox #(transaction) m2s);
        this.vif = vif;
        this.m2s = m2s;
        tr = new();
    endfunction

    task run();
        
        forever begin
            // wait for access state
            @(posedge vif.PREADY);
            tr.PSEL    = vif.PSEL;
            tr.PENABLE = vif.PENABLE;
            tr.PWRITE  = vif.PWRITE;
            tr.PADDR   = vif.PADDR;
            tr.PWDATA  = vif.PWDATA;
            tr.PRDATA  = vif.PRDATA;
            tr.PREADY  = vif.PREADY;
            tr.PSLVERR = vif.PSLVERR;

            if (tr.PWRITE) begin
                $display("[%0t] [MON] WRITE Operation at ADDR: %0d with DATA: %0d", $time, tr.PADDR, tr.PWDATA);
            end else begin
                $display("[%0t] [MON] READ Operation at ADDR: %0d with DATA: %0d", $time, tr.PADDR, tr.PRDATA);
            end

            m2s.put(tr.copy());
        end
    endtask

endclass

// we will creat temp to store data and compare when we need to match 

class scoreboard;

    transaction act, exp;
    mailbox #(transaction) g2s, m2s;

    localparam DEPTH = 1 << ADDR_WD;
    logic [DATA_WD-1:0] temp [0:DEPTH-1];


    event sconxt;

    function new(mailbox #(transaction) g2s, mailbox #(transaction) m2s);
        this.g2s = g2s;
        this.m2s = m2s;
        act = new();
        exp = new();
    endfunction

    task run();

        for (int i = 0; i < (2**ADDR_WD); i++) begin
            temp[i] = '0;
        end

        forever begin
            m2s.get(act);
            g2s.get(exp);
    
            exp.display("EXP");
            act.display("ACT");

            if (exp.PWRITE) begin
                // WRITE Operation
                temp[exp.PADDR] = exp.PWDATA;
                if (act.PSLVERR !== 0 || act.PREADY !== 1) begin
                    $error("[%0t] [SCO] WRITE Operation Error at ADDR: %0d", $time, exp.PADDR);
                end else begin
                    $display("[%0t] [SCO] WRITE Operation Success at ADDR: %0d with DATA: %0d",
                             $time, exp.PADDR, exp.PWDATA);
                end

            end else begin
                // READ Operation
                if (act.PRDATA !== temp[exp.PADDR]) begin
                    $error("[%0t] [SCO] READ Data Mismatch at ADDR: %0d, Expected: %0d, Got: %0d",
                           $time, exp.PADDR, temp[exp.PADDR], act.PRDATA);
                end else begin
                    $display("[%0t] [SCO] READ Data Match at ADDR: %0d, Data: %0d",
                             $time, exp.PADDR, act.PRDATA);
                end
                if (act.PSLVERR !== 0 || act.PREADY !== 1) begin
                    $error("[%0t] [SCO] READ Operation Error at ADDR: %0d", $time, exp.PADDR);
                end
            end
            $display(" =============================== ");
            -> sconxt;
        end
    endtask

endclass

class env;

    generator gen;
    driver    drv;
    monitor   mon;
    scoreboard sco;

    mailbox #(transaction) g2d, g2s, m2s;

    function new (virtual ABP_RAM_IF vif);
        g2d = new();
        g2s = new();
        m2s = new();

        gen = new(g2d, g2s);
        drv = new(vif, g2d);
        mon = new(vif, m2s);
        sco = new(g2s, m2s);

        sco.sconxt = gen.sconxt;

    endfunction

    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_none
        @(gen.done);
        $display("[%0t] [ENV] Test Completed", $time);
        $finish;
    endtask



endclass

module ABP_RAM_TB;

    ABP_RAM_IF vif();

    env e;

    ABP_RAM #(.ADDR_WD(ADDR_WD), .DATA_WD(DATA_WD)) dut (
        .PCLK    (vif.PCLK),
        .PRESETn (vif.PRESETn),
        .PSEL    (vif.PSEL),
        .PENABLE (vif.PENABLE),
        .PWRITE  (vif.PWRITE),
        .PADDR   (vif.PADDR),
        .PWDATA  (vif.PWDATA),
        .PRDATA  (vif.PRDATA),
        .PREADY  (vif.PREADY),
        .PSLVERR (vif.PSLVERR)
    );

    // Clock Generation
    initial begin
        vif.PCLK = 0;
        forever #5 vif.PCLK = ~vif.PCLK; // 10ns clock period
    end

    // Reset Generation
    initial begin
        vif.PRESETn = 0;
        #20;
        vif.PRESETn = 1;
    end

    initial begin
        fork
            e = new(vif);
            e.run();
        join_none
        #200000;
        $display("Testbench Timeout");
        $finish;
    end

endmodule : ABP_RAM_TB