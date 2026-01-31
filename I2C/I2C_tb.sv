`timescale 1ns/1ps

parameter data_wd = 8;
parameter addr_wd = 7;
parameter test_cnt = 20;


interface I2C_if;
    logic clk;
    logic rst_n;
    logic en, r_w;
    logic [data_wd-1 : 0] wdata;
    logic [addr_wd-1 : 0] addr;
    logic [data_wd-1 : 0] rdata;
    logic done;
endinterface : I2C_if

typedef enum logic { read, write} opr;



class transaction;

    opr       operation;
    bit       en;
    bit       r_w;
    rand bit  [data_wd-1 : 0] wdata;
    rand bit  [addr_wd-1 : 0] addr;
    bit       [data_wd-1 : 0] rdata;
    bit       done;

    function transaction copy();
        copy = new();
        copy = this;
    endfunction

    function void display(string tag);
        $display("[%0t] [%0s] en : %0b \t r_w : %0b \t wdata : %0b \t addr : %0b \t rdata : %0b \t done : %0b \t", $time, tag, en, r_w, wdata, addr, rdata, done);
    endfunction

    constraint rw_c {
        r_w dist { 0 :/ 50, 1 :/ 50};
    }

endclass

class generator;

    transaction tr;
    
    mailbox #(transaction) g2d, g2s;
    
    event drvnxt , sconext, test_done; 

    function new (mailbox #(transaction) g2d, g2s);
        this.g2d = g2d;
        this.g2s = g2s;
        tr       = new();
    endfunction

    task run;

        repeat(test_cnt) begin
            $display("==============================");
            assert (tr.randomize()) else $fatal("Randomization Failed");
            tr.display("GEN");
            g2d.put(tr.copy());
            g2s.put(tr.copy());
            @(drvnxt);
            @(sconext);

        end
        
        -> test_done;

    endtask

endclass


class driver;

    transaction tr;

    virtual I2C_if vif;

    mailbox #(transaction) g2d;

    event drvnxt;

    function new(mailbox #(transaction) g2d, virtual I2C_if vif);
        this.g2d = g2d;
        this.vif = vif;
    endfunction

    task run();

        forever begin

            tr = new();
            g2d.get(tr);
            tr.en  = 1;
            tr.r_w = 0;
            tr.display("DRV");


            // Write to MEMORY
            @(posedge vif.clk);
            vif.en    <= tr.en;
            vif.r_w   <= tr.r_w;
            vif.addr  <= tr.addr;
            vif.wdata <= tr.wdata; 
            repeat(2) @(posedge vif.clk);

            @(vif.done);
            vif.en <= 0;
            tr.en  <= 1;
            tr.r_w <= 1;  // read

            // Read From MEMORY
            @(posedge vif.clk);
            vif.en    <= tr.en;
            vif.r_w   <= tr.r_w;
            vif.addr  <= tr.addr;
            repeat(2) @(posedge vif.clk);
            @(vif.done);
            vif.en <= 0;

            -> drvnxt;

        end
        
    endtask

endclass

class monitor;

    transaction tr;

    virtual I2C_if vif;

    mailbox #(transaction) m2s;

    function new (mailbox #(transaction) m2s, virtual I2C_if vif);
        this.m2s = m2s;
        this.vif = vif;
    endfunction

    task run();

        forever begin
            tr = new();   
            @(posedge vif.done);
            if(vif.r_w) begin
            tr.rdata = vif.rdata;
                tr.done  = vif.done;
                tr.display("MON");
                m2s.put(tr);
            end
        end
        
    endtask

endclass


class scoreboard;

    transaction act, exp;

    mailbox #(transaction) g2s, m2s;
    event sconext;

    function new(mailbox #(transaction) g2s, m2s);

        this.g2s = g2s;
        this.m2s = m2s;

        act = new();
        exp = new();

    endfunction

    task run();
        
        forever begin

            m2s.get(act);
            exp.display("SCO-EXP");

            g2s.get(exp);
            act.display("SCO-ACT");

            if (act.rdata == exp.wdata)
                $display ("[%0t] [SCO] DATA MATCHES",$time);
            else
                $display ("[%0t] [SCO] DATA MISMATCHES",$time);

            $display("==============================");
            -> sconext;

        end

    endtask

endclass

class env;

    generator gen;
    driver    drv;
    monitor   mon;
    scoreboard sco;

    mailbox #(transaction) g2d, g2s, m2s;

    function new(virtual I2C_if vif);

        g2d = new();
        g2s = new();
        m2s = new();

        gen = new(g2d,g2s);
        drv = new(g2d,vif);
        mon = new(m2s,vif);
        sco = new(g2s,m2s);

        drv.drvnxt = gen.drvnxt;
        sco.sconext = gen.sconext;

    endfunction

    task run();

        fork 
            gen.run();
            mon.run();
            drv.run();
            sco.run();
        join_none

        @(gen.test_done);
        $display(" TEST DONE ");
        $finish;

    endtask

endclass


module I2C_tb;

    I2C_if vif();
    env e;

    // DUT Instantiation

    I2C #(
        .data_wd(data_wd),
        .addr_wd(addr_wd)
    ) I2C_instance (
        .clk(vif.clk),
        .rst_n(vif.rst_n),
        .en(vif.en),
        .r_w(vif.r_w),
        .wdata(vif.wdata),
        .addr(vif.addr),
        .rdata(vif.rdata),
        .done(vif.done)
    );




    // Clock Generation
    initial begin

        vif.clk = 0;
        forever #10 vif.clk <= !vif.clk;

    end

    // RESET 
    initial begin

        vif.rst_n <= 0;
        vif.wdata <= 0;
        vif.en    <= 0;
        vif.r_w   <= 0;
        vif.addr  <= 0;
        repeat(5) @(posedge vif.clk);
        vif.rst_n <= 1;

    end

    initial begin
        
        fork 
        e = new(vif);
        e.run();
        join_none

        #200000;
        $display(" TimeOUT ");
        $finish;

    end


endmodule
