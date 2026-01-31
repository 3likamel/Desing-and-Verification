`timescale 1ns/1ps


interface UART_RX_if();
    logic clk, rst;
    logic RX_IN;
    logic [5:0] Prescale;
    logic PAR_EN, PAR_TYP;
    logic stp_err, par_err;
    logic [7:0] P_DATA;
    logic data_valid;
endinterface


typedef enum logic [1:0] {
    VALID_FRAME,
    FALSE_START,
    FALSE_PARITY,
    FALSE_STOP
} test_kind_e;


class transaction;
    rand test_kind_e kind;
    rand bit [7:0] s_data;
    rand bit [5:0] Prescale;
    rand bit PAR_EN, PAR_TYP;

    bit [7:0] P_DATA;
    bit data_valid;
    bit par_err;
    bit stp_err;

    constraint prescale_c {
        Prescale inside {6'd4,6'd8,6'd16,6'd32};
    }

    constraint kind_c {
        kind dist {
            VALID_FRAME  := 60,
            FALSE_START  := 10,
            FALSE_PARITY := 15,
            FALSE_STOP   := 15
        };
    }

    function transaction copy();
        copy = new();
        copy = this;
    endfunction

    function void display(string tag);
        $display("[%0t] [%s] kind=%0d data=%0b prescale=%0d par_en=%0b par_typ=%0b dv=%0b pe=%0b se=%0b pdata=%0b",
            $time, tag, kind, s_data, Prescale, PAR_EN, PAR_TYP,
            data_valid, par_err, stp_err, P_DATA);
    endfunction
endclass


class generator;
    mailbox #(transaction) g2d, g2s;
    event frame_done;
    event test_done;

    function new(mailbox #(transaction) g2d, g2s);
        this.g2d = g2d;
        this.g2s = g2s;
    endfunction

    task run(int count);
        transaction tr;
        repeat (count) begin
            tr = new();
            assert(tr.randomize());
            tr.display("GEN");

            g2d.put(tr.copy());
            if (tr.kind == VALID_FRAME)
                g2s.put(tr.copy());

            @(frame_done); // wait till frame is observed
        end
        -> test_done;
    endtask
endclass


class driver;
    mailbox #(transaction) g2d;
    virtual UART_RX_if vif;
    event frame_done; 

    function new(mailbox #(transaction) g2d, virtual UART_RX_if vif);
        this.g2d = g2d;
        this.vif = vif;
    endfunction

    function bit calc_parity(bit [7:0] d, bit typ);
        return typ ? ~(^d) : ^d;
    endfunction

    task send_data(transaction tr);
        for (int i=0;i<8;i++) begin
            vif.RX_IN <= tr.s_data[i];
            repeat (tr.Prescale) @(posedge vif.clk);
        end
    endtask

    // ---------------- VALID ----------------
    task send_valid_frame(transaction tr);
        bit p;

        vif.Prescale <= tr.Prescale;
        vif.PAR_EN   <= tr.PAR_EN;
        vif.PAR_TYP  <= tr.PAR_TYP;

        vif.RX_IN <= 1;
        repeat (tr.Prescale) @(posedge vif.clk);

        vif.RX_IN <= 0;
        repeat (tr.Prescale) @(posedge vif.clk);

        send_data(tr);

        if (tr.PAR_EN) begin
            p = calc_parity(tr.s_data, tr.PAR_TYP);
            vif.RX_IN <= p;
            repeat (tr.Prescale) @(posedge vif.clk);
        end

        vif.RX_IN <= 1;
        repeat (tr.Prescale) @(posedge vif.clk);
    endtask

    // ---------------- FALSE START ----------------
    task false_start(transaction tr);
        vif.Prescale <= tr.Prescale;
        vif.RX_IN <= 1;
        repeat (tr.Prescale) @(posedge vif.clk);

        vif.RX_IN <= 0;
        repeat (tr.Prescale/3) @(posedge vif.clk);
        vif.RX_IN <= 1;

        repeat (tr.Prescale*2) @(posedge vif.clk);
    endtask

    // ---------------- FALSE PARITY ----------------
    task false_parity(transaction tr);
        vif.Prescale <= tr.Prescale;
        vif.PAR_EN   <= 1;
        vif.PAR_TYP  <= tr.PAR_TYP;

        vif.RX_IN <= 1;
        repeat (tr.Prescale) @(posedge vif.clk);

        vif.RX_IN <= 0;
        repeat (tr.Prescale) @(posedge vif.clk);

        send_data(tr);

        vif.RX_IN <= ~calc_parity(tr.s_data, tr.PAR_TYP);
        repeat (tr.Prescale) @(posedge vif.clk);

        vif.RX_IN <= 1;
        repeat (tr.Prescale) @(posedge vif.clk);
    endtask

    // ---------------- FALSE STOP ----------------
    task false_stop(transaction tr);
        vif.Prescale <= tr.Prescale;
        vif.PAR_EN   <= 0;

        vif.RX_IN <= 1;
        repeat (tr.Prescale) @(posedge vif.clk);

        vif.RX_IN <= 0;
        repeat (tr.Prescale) @(posedge vif.clk);

        send_data(tr);

        vif.RX_IN <= 0; // wrong stop
        repeat (tr.Prescale) @(posedge vif.clk);

        vif.RX_IN <= 1;
        repeat (tr.Prescale) @(posedge vif.clk);
    endtask

    task run();
        transaction tr;
        forever begin
            g2d.get(tr);
            tr.display("DRV");

            case (tr.kind)
                VALID_FRAME : send_valid_frame(tr);
                FALSE_START : false_start(tr);
                FALSE_PARITY: false_parity(tr);
                FALSE_STOP  : false_stop(tr);
            endcase
        end
    endtask
endclass


class monitor;
    mailbox #(transaction) m2s;
    virtual UART_RX_if vif;
    event frame_seen;

    function new(mailbox #(transaction) m2s, virtual UART_RX_if vif);
        this.m2s = m2s;
        this.vif = vif;
    endfunction

    task run();
        transaction tr;
        forever begin
            @(posedge vif.data_valid or posedge vif.par_err or posedge vif.stp_err);
            tr = new();
            tr.P_DATA     = vif.P_DATA;
            tr.data_valid = vif.data_valid;
            tr.par_err    = vif.par_err;
            tr.stp_err    = vif.stp_err;
            tr.display("MON");
            m2s.put(tr);
            -> frame_seen; 
        end
    endtask
endclass


class scoreboard;
    mailbox #(transaction) g2s, m2s;

    function new(mailbox #(transaction) g2s, m2s);
        this.g2s = g2s;
        this.m2s = m2s;
    endfunction

    task run();
        transaction exp, act;
        forever begin
            m2s.get(act);

            if (act.par_err)
                $display("[SCO] EXPECTED PARITY ERROR");
            else if (act.stp_err)
                $display("[SCO] EXPECTED STOP ERROR");
            else begin
                g2s.get(exp);
                if (exp.s_data == act.P_DATA)
                    $display("[SCO] FRAME OK : %b", act.P_DATA);
                else
                    $error("[SCO] DATA MISMATCH");
            end
            $display("=================================");
        end
    endtask
endclass


class env;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;

    mailbox #(transaction) g2d, g2s, m2s;

    function new(virtual UART_RX_if vif);
        g2d = new(); 
        g2s = new();
        m2s = new();
        gen = new(g2d, g2s);
        drv = new(g2d, vif);
        mon = new(m2s, vif);
        sco = new(g2s, m2s);

        gen.frame_done = mon.frame_seen;
        drv.frame_done = mon.frame_seen;
    endfunction

    task run();
        fork
            gen.run(20);
            drv.run();
            mon.run();
            sco.run();
        join_none
        @(gen.test_done);
        $finish;
    endtask
endclass


module uart_rx_tb;

    UART_RX_if vif();
    env e;

    UART_RX dut (
        .clk(vif.clk),
        .rst(vif.rst),
        .RX_IN(vif.RX_IN),
        .Prescale(vif.Prescale),
        .PAR_EN(vif.PAR_EN),
        .PAR_TYP(vif.PAR_TYP),
        .stp_err(vif.stp_err),
        .par_err(vif.par_err),
        .P_DATA(vif.P_DATA),
        .data_valid(vif.data_valid)
    );

    initial begin
        vif.clk = 0;
        forever #10 vif.clk = ~vif.clk;
    end

    initial begin
        vif.rst = 0;
        vif.RX_IN = 1;
        repeat (5) @(posedge vif.clk);
        vif.rst = 1;

        e = new(vif);
        e.run();

        $display("TEST DONE");
    end

endmodule
