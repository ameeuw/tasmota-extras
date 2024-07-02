var pq_app = module('pq_app')

class PriceChart
    var main_cont, wrapper, chart, series
    def init()
        self.main_cont = lv.obj(lv.scr_act())
        self.main_cont.set_size(480, 240)
        self.main_cont.set_pos(0, 0)

        self.wrapper = lv.obj(self.main_cont)
        self.wrapper.remove_style_all()
        self.wrapper.set_size(lv.pct(100), lv.pct(100))
        self.wrapper.set_flex_flow(lv.FLEX_FLOW_COLUMN)

        self.chart = lv.chart(self.wrapper)
        self.chart.set_width(lv.pct(100))
        self.chart.set_flex_grow(1)
        self.chart.set_type(lv.CHART_TYPE_BAR)
        self.chart.set_range(lv.CHART_AXIS_PRIMARY_Y, 0, 20)
        # self.chart.set_axis_tick(lv.CHART_AXIS_PRIMARY_Y, 1, 1, 10, 2, true, 20)
        # self.chart.set_axis_tick(lv.CHART_AXIS_PRIMARY_X, 10, 5, 10, 3, true, 20)
        self.chart.set_point_count(48)
        self.chart.set_style_radius(0,0)

        self.series = self.chart.add_series(lv.color(0x6bbf70), lv.CHART_AXIS_PRIMARY_Y)
    end

    def update_series(payload)
        self.chart.remove_series(self.series)
        self.series = self.chart.add_series(lv.color(0x6bbf70), lv.CHART_AXIS_PRIMARY_Y)
        var scale = 1000000
        for item:payload["data"]
            self.chart.set_next_value(self.series, item["value"] / scale)
        end
    end
end

class QrCode
    var qr
    def init()
        self.qr = lv.qrcode(lv.scr_act())
        self.qr.set_size(200)
        self.qr.set_dark_color(lv.color(0x000000))
        self.qr.set_light_color(lv.color(0xffffff))
        self.qr.set_pos(140, 40)
    end

    def update(text)
        self.qr.update(text, size(text))
    end

    def delete()
        self.qr.delete()
    end
end

class PqApp
    var pq, chart, qr, auid
    def init()
        if self.qr
            self.qr.delete()
        end
        self.start()

    end

    def start()
        if !tasmota.wifi()["up"]
            print(wd)
            print("WiFi not available - timeout 10 seconds")
            tasmota.set_timer(10000,/ -> self.start())
        return
        else

            import persist
            import powerquartier


            if persist.has("email") && persist.has("password")
                var email = persist.email
                var password = bytes().fromb64(persist.password).asstring()
                self.pq = powerquartier.Client(email, password)

                if persist.has("auid")
                    self.auid = persist.auid
                    self.chart = PriceChart()
                    self.updateChart()
                else
                    var ip = tasmota.wifi()["ip"]
                    self.qr = QrCode()
                    self.qr.update("http://" + ip + "/pq_accounts")
                end
            else
                var ip = tasmota.wifi()["ip"]
                self.qr = QrCode()
                self.qr.update("http://" + ip + "/pq_credentials")
            end
        end

    end

    def update()
        if self.pq && self.chart && self.auid
            self.updateChart()
        else
            self.init()
        end
    end

    def updateChart()
        import string
        var now = tasmota.rtc()
        var nowQuantized = now["utc"] - (now["utc"] % (60 * 60 * 24))
        var start = tasmota.strftime("%Y-%m-%dT%H:%M:%S", nowQuantized)
        var stop = tasmota.strftime("%Y-%m-%dT%H:%M:%S", nowQuantized + (48 * 60 * 60))
        print("getting price from " + start + " to " + stop)
        var uri = "/billing/accounts/" + self.auid + string.format("/avgprice?include_taxes=true&start=%s&stop=%s&interval=1h", start, stop)
        self.chart.update_series(self.pq.get_uri(uri))
    end
end

pq_app.PqApp = PqApp
pq_app.QrCode = QrCode
pq_app.PriceChart = PriceChart

return pq_app
