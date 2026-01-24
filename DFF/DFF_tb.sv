int clk_period = 20;

interface dff_if;
    logic rst_n;
    logic clk;
    logic d;
    logic q;
endinterface

class transaction;
rand    bit rst_n;
rand    bit d;
        bit q;

    function transaction copy ();
        copy = new();
        copy.rst_n = this.rst_n;
        copy.d     = this.d;
        copy.q     = this.q;
    endfunction

    function void  display();
        $display("D %0d \t rst_n %0d",d,rst_n);
    endfunction

    constraint rst_c {
        rst_n dist {0 := 10 , 1 := 90};
    }

endclass

class generator;

    transaction trans;
    mailbox #(transaction) gen2drv;
    event done;

    function new (input mailbox #(transaction) gen2drv);
        this.gen2drv = gen2drv;
        trans = new();
    endfunction

    task run();
        $display("---------------------------------------------------------------");
        for (int i=0 ; i<20 ; i++) begin 
            $display("---------------------------------------------------------------");
            assert(trans.randomize) else $error("Randomiztion Failed");
            $display("[%0t] [GEN] sent data to driver",$time);
            gen2drv.put(trans.copy());
            trans.copy.display();
            #(clk_period*2);
        end
        -> done;
    endtask
endclass

class driver;

    virtual dff_if drv_if;
    transaction data;
    mailbox #(transaction) gen2drv;

    function new (input mailbox #(transaction) gen2drv);
        this.gen2drv = gen2drv;
        data = new();
    endfunction

    task run();
        forever begin
            gen2drv.get(data);
            $display("[%0t] [DRV] apply Data to DUT",$time);
            data.display();
            drv_if.rst_n <= data.rst_n;
            drv_if.d <= data.d;
            @(posedge drv_if.clk);
        end
    endtask
endclass

class monitor;

    virtual dff_if dff_resp;
    transaction resp;
    mailbox #(transaction) mon2sco;

    function new (input mailbox #(transaction) mon2sco);
        this.mon2sco = mon2sco;
        resp = new();
    endfunction

    task run();
    forever begin
        @(posedge dff_resp.clk);
        @(posedge dff_resp.clk);
        resp.d = dff_resp.d;
        resp.rst_n = dff_resp.rst_n;
        resp.q = dff_resp.q;
        $display("[%0t] [MON] Received Response Q = %0d and Sent it to Scoreboard",$time,resp.q);
        resp.display();
        mon2sco.put(resp.copy());
    end
    endtask

endclass

class scoreboard;

    transaction data;
    mailbox #(transaction) mon2sco;

    function new (input mailbox #(transaction) mon2sco);
        this.mon2sco = mon2sco;
        data = new();
    endfunction

    task run();
        forever begin
             mon2sco.get(data);
             $display("[%0t] [SCO] Received Data Q = %0d",$time,data.q);
             data.display();
             if (data.rst_n == 0 && data.q == 0)
                $display("[SCO] Data Matches");
             else if (data.q == data.d)
                $display("[SCO] Data Matches");
             else
                $error("[SCO] Data MisMatches");
             $display("---------------------------------------------------------------");
        end
        
    endtask

endclass

module DFF_tb; // @suppress "File contains multiple design units"

    dff_if dff ();
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard sco;
    mailbox #(transaction) gen2drv;
    mailbox #(transaction) mon2sco;

    DFF DFF_instance (
        .clk(dff.clk),
        .rst_n(dff.rst_n),
        .d(dff.d),
        .q(dff.q)
    );

    always #(clk_period/2) dff.clk <= ~dff.clk;

    initial begin
        dff.clk = 0;
        gen2drv = new();
        mon2sco = new();
        gen =  new(gen2drv);
        drv =  new(gen2drv);
        mon =  new(mon2sco);
        sco =  new(mon2sco);
        mon.dff_resp = dff;
        drv.drv_if   = dff;
    end

    initial begin
        fork
            gen.run;
            drv.run;
            mon.run;
            sco.run;
        join_none
        wait(gen.done.triggered);
        $finish;
    end
    
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end
    

endmodule

