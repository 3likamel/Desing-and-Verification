`timescale 1ns/1ps

int clk_period = 20;

parameter  width = 8;
parameter  dipth = 32;
//parameter  addr_width = $clog2(dipth);

interface FIFO_if;
    logic      clk,rst;
    logic      rd,wr;
    logic      full,empty;
    logic      [width-1:0] din;
    logic      [width-1:0] dout;
endinterface

class transaction;
    
   // bit rst;
    randc bit rd,wr;
    bit full,empty;
    randc bit [width-1:0] din;
    bit [width-1:0] dout;

    function transaction copy();
        copy = new();
        copy.rd = this.rd;
        copy.wr = this.wr;
        copy.full = this.full;
        copy.empty = this.empty;
        copy.din = this.din;
        copy.dout = this.dout;
    endfunction

    constraint rd_wr_c {
        !(rd && wr);
    }

    function void display(input string tag);
        $display("[%0s] rd = %0d \t wr = %0d \t full = %0d \t empty = %0d \t din = %0d \t dout = %0d \t",tag,rd,wr,full,empty,din,dout);
    endfunction

endclass

class generator;

    transaction trans;
    mailbox #(transaction) gen2drv;
    mailbox #(transaction) gen2sco;

    event sconext;
    event done;

    function new(inout mailbox #(transaction) gen2drv,gen2sco);
        this.gen2sco = gen2sco;
        this.gen2drv = gen2drv;
        trans = new();
    endfunction

    task run();
        $display("--------------------------------------------------------------------");
        repeat (2*dipth) begin
            $display("--------------------------------------------------------------------");
            assert(trans.randomize()) else $error("Randomization Failed");
            $display("[%0t] [GEN] Send Data to Driver",$time);
            gen2drv.put(trans.copy());
            gen2sco.put(trans.copy());
            trans.display("GEN");
            @(sconext);
        end
        ->done;
    endtask
endclass

class driver;

    transaction data;
    virtual FIFO_if drv_fifo;
    mailbox #(transaction) gen2drv;

    function new(inout mailbox #(transaction) gen2drv);
        this.gen2drv = gen2drv;
        data = new();
    endfunction

    task run;
        forever begin
            gen2drv.get(data);
            @(posedge drv_fifo.clk);
          //  drv_fifo.rst   <= 0;
            drv_fifo.din   <= data.din;
            drv_fifo.wr    <= data.wr;
            drv_fifo.rd    <= data.rd;
            $display("[%0t] [DRV] Apply data to DUT",$time);
            data.display("DRV");
        end
        
    endtask
endclass

class monitor;
    transaction data;
    virtual FIFO_if mon_fifo;
    mailbox #(transaction) mon2sco;

    function new(inout mailbox #(transaction) mon2sco);
        this.mon2sco = mon2sco;
    endfunction

    task run();
        forever begin
            @(posedge mon_fifo.clk);
            @(posedge mon_fifo.clk);
            data = new();
            data.rd      = mon_fifo.rd;
            data.wr      = mon_fifo.wr;
            data.empty   = mon_fifo.empty;
            data.full    = mon_fifo.full;
            data.din     = mon_fifo.din;
            data.dout    = mon_fifo.dout;
            $display("[%0t] [MON] SAMPLED DUT",$time);
            data.display("MON");
            mon2sco.put(data);
        end
    endtask

endclass

class scoreboard;

    // Transaction from monitor
    transaction data;
    event sconext;
    // Mailbox
    mailbox #(transaction) mon2sco;

    // Reference FIFO model
    bit [width-1:0] fifo_q[$];

    // Read pipeline
    bit              rd_pending;
    bit [width-1:0]  exp_data;

    function new(input mailbox #(transaction) mon2sco);
        this.mon2sco = mon2sco;
        data = new();
        rd_pending = 0;
    endfunction

    task run();
        forever begin
            mon2sco.get(data);

            $display("[%0t] [SCO] Checking", $time);
            data.display("SCO");

            // -------------------------------------------------
            // 1) WRITE handling (immediate)
            // -------------------------------------------------
            if (data.wr && !data.full) begin
                fifo_q.push_back(data.din);
                $display("[SCO] REF WRITE %0d (depth=%0d)",
                         data.din, fifo_q.size());
            end

            // -------------------------------------------------
            // 2) REGISTER READ intent (no compare yet)
            // -------------------------------------------------
            if (data.rd && !data.empty) begin
                rd_pending = 1;
                exp_data = fifo_q.pop_front();
            end

            // -------------------------------------------------
            // 3) COMPARE (one cycle after valid read)
            // -------------------------------------------------
            else if (rd_pending) begin
                if (data.dout === exp_data)
                    $display("[SCO] READ MATCH exp=%0d act=%0d",
                             exp_data, data.dout);
                else
                    $error("[SCO] READ MISMATCH exp=%0d act=%0d",
                           exp_data, data.dout);
                rd_pending = 0;
            end

            // -------------------------------------------------
            // 4) INFO (legal but interesting cases)
            // -------------------------------------------------
            if (data.rd && data.empty)
                $display("[SCO] INFO: Read attempted while FIFO empty");

            if (data.wr && data.full)
                $display("[SCO] INFO: Write attempted while FIFO full");

            // -------------------------------------------------
            // 5) FLAG sanity check (only when stable)
            // -------------------------------------------------
           // FLAG sanity check (only when stable)
if (!rd_pending && !(data.wr && !data.full)) begin
  if (data.empty !== (fifo_q.size() == 0))
    $error("[SCO] EMPTY FLAG WRONG (qsize=%0d, empty=%0b)",
           fifo_q.size(), data.empty);
end


            $display("----------------------------------------------------");
            ->sconext;
        end
    endtask

endclass


class enviroment;

   // transaction tras;
    generator   gen;
    driver      drv;
    monitor     mon;
    scoreboard  sco;

    virtual FIFO_if FIFO_I;

    event sconext;

    mailbox #(transaction) gen2dsco;
    mailbox #(transaction) gen2drv;
    mailbox #(transaction) mon2sco;

    function new(input virtual FIFO_if fifo_inf);
        gen2dsco = new();
        gen2drv  = new();
        mon2sco  = new();
        gen = new(gen2drv,gen2dsco);
        drv = new(gen2drv);
        mon = new(mon2sco);
        sco = new(mon2sco);
        drv.drv_fifo = fifo_inf;
        mon.mon_fifo = fifo_inf;
        FIFO_I  = fifo_inf; 
        gen.sconext  = sconext;
        sco.sconext  = sconext;
    endfunction

    task pre_test();
        FIFO_I.rst = 1;
        repeat(3)@(posedge FIFO_I.clk);
        if (FIFO_I.dout == 0)
            $display("RESET COMPLETED");
        else
            $display("RESET FAILED");
        FIFO_I.rst = 0;
        repeat(2)@(posedge FIFO_I.clk);
    endtask

    task test();
        fork
            gen.run;
            drv.run;
            mon.run;
            sco.run;
        join_none
        wait(gen.done.triggered);
        $finish;
    endtask

    task post_test();
        $dumpfile("dump.vcd");
        $dumpvars;
    endtask

    task run();
        pre_test();
        test();
        post_test();
    endtask

endclass

module FIFO_tb; // @suppress "File contains multiple design units"

    enviroment env;
    FIFO_if fifo_inf();

    FIFO #(
        .width(width),
        .dipth(dipth)
    ) FIFO_instance (
        .clk(fifo_inf.clk),
        .rst(fifo_inf.rst),
        .rd(fifo_inf.rd),
        .wr(fifo_inf.wr),
        .din(fifo_inf.din),
        .full(fifo_inf.full),
        .empty(fifo_inf.empty),
        .dout(fifo_inf.dout)
    );

    always #(clk_period) fifo_inf.clk <= ~fifo_inf.clk;

    initial begin
        fifo_inf.clk = 0;
    end
    

    initial begin
     //   env.FIFO_I = fifo_inf;
        env = new(fifo_inf);
        env.run;
    end
    

endmodule