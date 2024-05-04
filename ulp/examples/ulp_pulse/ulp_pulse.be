class PULSE : Driver
    var edge_count, io_number, debounce_max_count, pulse_min, pulse_min_ms
    var reg_debounce_max_count, reg_io_number, reg_edge_count, reg_init_done, reg_pulse_min
    var ulp_sleep_time
    
    def get_code()
      return bytes().fromb64("{{code_b64}}")
    end
  
    def init()
      self.ulp_sleep_time = 4000
      self.reg_debounce_max_count = {{debounce_max_count}}
      self.reg_init_done = {{init_done}}
      self.reg_edge_count = {{edge_count}}
      self.reg_pulse_min = {{pulse_min}}
      self.reg_io_number = {{io_number}}
      import ULP
      self.initULP()
      if (ULP.get_mem(self.reg_init_done) != 1337)
          self.initULP()
          ULP.set_mem(self.reg_init_done,1337)
      end
      tasmota.add_cron("0 */1 * * * *", / -> self.update_energy(), "every_5_minutes")
    end
  
    def initULP()
      import ULP
      ULP.wake_period(0,self.ulp_sleep_time)
      self.debounce_max_count = 5
      self.io_number = ULP.gpio_init(0,0) # GPIO 0 to input
      var c = self.get_code()
      ULP.load(c)
      ULP.set_mem({{pulse_edge}}, 1)
      ULP.set_mem({{next_edge}}, 1)
      ULP.set_mem(self.reg_debounce_max_count,self.debounce_max_count) # debounce_max_count
      ULP.set_mem(self.reg_io_number,self.io_number) # rtc_gpio_number
      ULP.run()
    end
  
    #- read from RTC_SLOW_MEM, measuring was done by ULP -#
    def read_counts()
      import ULP
      self.edge_count = ULP.get_mem(self.reg_edge_count)
      self.pulse_min = ULP.get_mem(self.reg_pulse_min)
      self.pulse_min_ms = self.pulse_min * self.ulp_sleep_time / 1000
      self.debounce_max_count = ULP.get_mem(self.reg_debounce_max_count)
    end
  
    #- read from RTC_SLOW_MEM, measuring was done by ULP -#
    def update_energy()
      var whPerPulse = 5
      var wPerPeriodMs = whPerPulse * 3600 * 1000
      energy.total += self.edge_count * whPerPulse
      print(self.pulse_min_ms)
      energy.active_power = wPerPeriodMs / self.pulse_min_ms
      self.set_edge_count(0)
      self.reset_pulse_min()
    end
  
    def set_debounce_max_count(count)
      import ULP
      ULP.set_mem(self.reg_debounce_max_count,count) #debounce_max_count
      return ULP.get_mem(self.reg_debounce_max_count)
    end
  
    def set_edge_count(count)
      import ULP
      ULP.set_mem(self.reg_edge_count,count) #edge_count
      return ULP.get_mem(self.reg_edge_count)
    end
  
    def reset_pulse_min()
      import ULP
      ULP.set_mem(self.reg_pulse_min, 0) #pulse_min
      return ULP.get_mem(self.reg_pulse_min)
    end
  
    #- trigger a read every second -#
    def every_second()
      self.read_counts()
    end
  
    #- display sensor value in the web UI -#
    def web_sensor()
      import string
      var msg = string.format(
               "{s}<hr>{m}<hr>{e}"
               "{s}Pulse counter{m}ULP readings:{e}"
               "{s}Pulse count {m}%i{e}"..
               "{s}Pulse min {m}%i ms{e}"..
               "{s}Debounce {m}%i{e}",
                    self.edge_count, self.pulse_min_ms, self.debounce_max_count)
      tasmota.web_send_decimal(msg)
    end
  
    #- add sensor value to teleperiod -#
    def json_append()
      import string
      var msg = string.format(",\"Pulse\":{\"edge\":%i}",
                                   self.edge_count)
      tasmota.response_append(msg)
    end
  
  end
  
  pulse = PULSE()
  tasmota.add_driver(pulse)
  
  def usleep(cmd, idx, payload, payload_json)
      import ULP
      ULP.sleep(int(payload))
  end
  tasmota.add_cmd('usleep', usleep)
  
  def pulse_debounce(cmd, idx, payload, payload_json)
      import ULP
      import string
      var result
      if payload != ""
          result = pulse.set_debounce_max_count(int(payload))
      end
      tasmota.resp_cmnd(string.format('{"debounce count":%i}', result))
  end
  tasmota.add_cmd('pulse_debounce', pulse_debounce)
  
  def pulse_edge(cmd, idx, payload, payload_json)
      import ULP
      import string
      var result
      if payload != ""
          result = pulse.set_edge_count(int(payload))
      end
      tasmota.resp_cmnd(string.format('{"pulse edge":%i}', result))
  end
  tasmota.add_cmd('pulse_edge', pulse_edge)
  
  def pulse_min(cmd, idx, payload, payload_json)
      import ULP
      import string
      tasmota.resp_cmnd(string.format('{"pulse min":%i}', pulse.reset_pulse_min()))
  end
  tasmota.add_cmd('pulse_min', pulse_min)