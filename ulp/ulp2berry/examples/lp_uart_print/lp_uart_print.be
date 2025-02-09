var lp_uart_print = module('lp_uart_print')

class lp_uart_print_class : Driver
    var ulp_sleep_time, ulp_iteration, ulp_sml_state, ulp_print_variable, ulp_sml_byte, ulp_sml_t1wh
    
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

    def read_state()
      import ULP
      return ULP.get_mem({{ulp_sml_state}})
    end

    def read_print_variable()
      import ULP
      return ULP.get_mem({{ulp_print_variable}})
    end

    def read_byte()
      import ULP
      return ULP.get_mem({{ulp_sml_byte}})
    end

    def read_t1wh()
      import ULP
      return ULP.get_mem({{ulp_sml_t1wh}})
    end

    def set_print_variable(value)
      import ULP
      ULP.set_mem({{ulp_print_variable}},value)
      return ULP.get_mem({{ulp_print_variable}})
    end

    def set_byte(value)
      import ULP
      ULP.set_mem({{ulp_sml_byte}},value)
      return ULP.get_mem({{ulp_sml_byte}})
    end

    #- trigger a read every second -#
    def every_second()
      self.ulp_iteration = self.read_iteration()
      self.ulp_print_variable = self.read_print_variable()
      self.ulp_sml_state = self.read_state()
      self.ulp_sml_byte = self.read_byte()
      self.ulp_sml_t1wh = self.read_t1wh()
    end
  
    #- display sensor value in the web UI -#
    def web_sensor()
      import string
      var msg = string.format(
               "{s}<hr>{m}<hr>{e}"
               "{s}ULP Variable{m}value:{e}"
               "{s}iteration{m}%i{e}"..
               "{s}state{m}%i{e}"..
               "{s}byte{m}%i{e}"..
               "{s}t1wh{m}%i{e}"..
               "{s}print_variable{m}%i{e}",
               self.ulp_iteration,
               self.ulp_sml_state,
               self.ulp_sml_byte,
               self.ulp_sml_t1wh,
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

  def set_byte(cmd, idx, payload, payload_json)
    import ULP
    import string
    var result
    if payload != ""
      result = lp_uart_print.lp_uart_print.set_byte(int(payload))
    end
    tasmota.resp_cmnd(string.format('{"byte":%i}', result))
  end
  tasmota.add_cmd('lp_uart_byte', set_byte)
end

return lp_uart_print