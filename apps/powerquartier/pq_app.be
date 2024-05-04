var pq_app = module('pq_app')

class PqApp
    var pq, chart, qr, auid
    def init()
        import persist
        import powerquartier
        if self.qr
            self.qr.delete()
        end

        if persist.has("email") && persist.has("password")
            var email = persist.email
            var password = bytes().fromb64(persist.password).asstring()
            self.pq = powerquartier.Client(email, password)

            if persist.has("auid")
                self.auid = persist.auid
                self.chart = powerquartier.PriceChart()
                self.updateChart()
            else
                var ip = tasmota.wifi()["ip"]
                self.qr = powerquartier.QrCode()
                self.qr.update("http://" + ip + "/pq_accounts")
            end
        else
            var ip = tasmota.wifi()["ip"]
            self.qr = powerquartier.QrCode()
            self.qr.update("http://" + ip + "/pq_credentials")
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

return pq_app
