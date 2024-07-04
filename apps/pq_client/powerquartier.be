var powerquartier = module('powerquartier')

class Client
    var base_url, email, password
    def init(email, password, base_url)
        self.email = email
        self.password = password
        if !base_url
            import persist
            if ! persist.has("base_url")
                self.base_url = "https://develop.exnaton.com/api/v2"
            else
                self.base_url = persist.base_url
            end
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
        print("response: " + response)
        return json.load(response)
    end

    def post(uri, payload)
        import json
        var cl = webclient()
        var cookie = self.post_auth()
        cl.begin(self.base_url + uri)
        cl.add_header("Accept", "*/*")
        cl.add_header("cookie", cookie)
        var code=cl.POST(json.dumps(payload))
        var response=cl.get_string()
        return json.load(response)
    end
end

powerquartier.Client=Client
return powerquartier