var lp_uart_print = module('lp_uart_print')

class lp_uart_print_class : Driver
    var ulp_sleep_time, ulp_iteration, ulp_print_variable, ulp_sml_t1wh, ulp_sml_sumwh, ulp_sml_t1wh_scaler, ulp_sml_sumwh_scaler
    
    def get_code()
      return bytes().fromb64("{{code_b64}}")
    end
  
    def init()
      self.ulp_sleep_time = 5 * 1000 * 1000
      import ULP
      ULP.uart_init(4,5,9600,serial.SERIAL_8N1)
      self.init_ulp()
    end
  
    def init_ulp()
      import ULP
      ULP.wake_period(0,self.ulp_sleep_time)
      var c = self.get_code()
      ULP.load(c)
      ULP.run()
    end  

    def read_iteration()
      import ULP
      return ULP.get_mem({{ulp_iteration}})
    end

    def read_print_variable()
      import ULP
      return ULP.get_mem({{ulp_print_variable}})
    end

    def read_t1wh()
      import ULP
      return ULP.get_mem({{ulp_sml_t1wh}})
    end

    def read_t1wh_scaler()
      import ULP
      return ULP.get_mem({{ulp_sml_t1wh_scaler}})
    end

    def read_sumwh()
      import ULP
      return ULP.get_mem({{ulp_sml_sumwh}})
    end

    def read_sumwh_scaler()
      import ULP
      return ULP.get_mem({{ulp_sml_sumwh_scaler}})
    end

    def set_print_variable(value)
      import ULP
      ULP.set_mem({{ulp_print_variable}},value)
      return ULP.get_mem({{ulp_print_variable}})
    end


    #- trigger a read every second -#
    def every_second()
      self.ulp_iteration = self.read_iteration()
      self.ulp_print_variable = self.read_print_variable()
      self.ulp_sml_t1wh = self.read_t1wh()
      self.ulp_sml_t1wh_scaler = self.read_t1wh_scaler()
      self.ulp_sml_sumwh = self.read_sumwh()
      self.ulp_sml_sumwh_scaler = self.read_sumwh_scaler()
    end
  
    #- display sensor value in the web UI -#
    def web_sensor()
      import string
      var msg = string.format(
               "{s}<hr>{m}<hr>{e}"
               "{s}ULP Variable{m}value:{e}"
               "{s}iteration{m}%i{e}"..
               "{s}t1wh{m}%i{e}"..
               "{s}t1wh_scaler{m}%i{e}"..
               "{s}sumwh{m}%i{e}"..
               "{s}sumwh_scaler{m}%i{e}"..
               "{s}print_variable{m}%i{e}",
               self.ulp_iteration,
               self.ulp_sml_t1wh,
               self.ulp_sml_t1wh_scaler,
               self.ulp_sml_sumwh,
               self.ulp_sml_sumwh_scaler,
               self.ulp_print_variable)
      tasmota.web_send_decimal(msg)
    end
  
    #- add sensor value to teleperiod -#
    def json_append()
      import string
      var msg = string.format(",\"ULP\":{\"iteration\":%i}",
                                   self.ulp_iteration)
      tasmota.response_append(msg)
    end
end
lp_uart_print.lp_uart_print = lp_uart_print_class()


if tasmota
  tasmota.add_driver(lp_uart_print.lp_uart_print)

  def set_print_variable(cmd, idx, payload, payload_json)
    import ULP
    import string
    var result
    if payload != ""
        result = lp_uart_print.lp_uart_print.set_print_variable(int(payload))
    end
    tasmota.resp_cmnd(string.format('{"print variable":%i}', result))
  end
  tasmota.add_cmd('lp_uart_print_variable', set_print_variable)

end

return lp_uart_print