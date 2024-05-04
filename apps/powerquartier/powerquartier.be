var powerquartier = module('powerquartier')

class Client
    var base_url, email, password
    def init(email, password, base_url)
        self.email = email
        self.password = password
        if !base_url
            self.base_url = "https://develop.exnaton.com/api/v2"
        else
            self.base_url = base_url
        end
    end

    def post_auth()
        import string
        var cl = webclient()
        cl.collect_headers("Set-Cookie")
        cl.begin(self.base_url + "/auth/auth")
        cl.add_header("Content-Type", "application/json")
        var code=cl.POST('{"email":"'+self.email+'","password":"'+self.password+'"}')
        var cookies = cl.get_header("Set-Cookie")
        var cookie = string.split(cookies, ";")[0]
        return cookie
    end

    def get_uri(uri)
        import json
        var cl = webclient()
        var cookie = self.post_auth()
        cl.begin(self.base_url + uri)
        cl.add_header("Accept", "*/*")
        cl.add_header("cookie", cookie)
        cl.GET()
        var response=cl.get_string()
        return json.load(response)
    end
end

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

powerquartier.Client=Client
powerquartier.QrCode=QrCode
powerquartier.PriceChart=PriceChart
return powerquartier