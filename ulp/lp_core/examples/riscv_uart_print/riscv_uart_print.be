class riscv_uart_print : Driver
    var ulp_sleep_time, ulp_iteration, ulp_print_variable
    
    def get_code()
      return bytes().fromb64("{{code_b64}}")
    end
  
    def init()
      self.ulp_sleep_time = 20 * 1000
      import ULP
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

    def set_print_variable(value)
      import ULP
      ULP.set_mem({{ulp_print_variable}},value)
      return ULP.get_mem({{ulp_print_variable}})
    end

    #- trigger a read every second -#
    def every_second()
      self.ulp_iteration = self.read_iteration()
      self.ulp_print_variable = self.read_print_variable()
    end
  
    #- display sensor value in the web UI -#
    def web_sensor()
      import string
      var msg = string.format(
               "{s}<hr>{m}<hr>{e}"
               "{s}ULP Variable{m}value:{e}"
               "{s}iteration{m}%i{e}"..
               "{s}print_variable{m}%i{e}",
               self.ulp_iteration,
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
riscv_uart_print = riscv_uart_print()
tasmota.add_driver(riscv_uart_print)

def set_print_variable(cmd, idx, payload, payload_json)
  import ULP
  import string
  var result
  if payload != ""
      result = riscv_uart_print.set_print_variable(int(payload))
  end
  tasmota.resp_cmnd(string.format('{"print variable":%i}', result))
end
tasmota.add_cmd('riscv_uart_print_variable', set_print_variable)
