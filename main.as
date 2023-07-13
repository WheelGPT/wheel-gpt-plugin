[Setting category="Info" name="Enabled"]
bool enabled = false;

[Setting category="Dev" name="Debug"]
bool debug = false;

[Setting category="Dev" name="TestLocal"]
bool testLocal = false;

[Setting category="Info" name="password" password]
string password = "";

[Setting category="Info" name="Channel"]
string channel = "";


Net::HttpRequest@ PostAsync(const Json::Value &in data) {
    auto request = Net::HttpRequest();
    request.Method = Net::HttpMethod::Post;
    request.Body = Json::Write(data);
    request.Headers["Content-Type"] = 'application/json';
    if (!testLocal) {
        request.Url = "https://wheelgpt.sowiemarkus.com/newpb";
    } else {
        request.Url = "http://localhost:1330/newpb";
    }
    request.Start();

    int count = 0;
    while(!request.Finished()) {
        count++;
        sleep(1000);
        if (count == 10) {
            break;
        }
    }
    return request;
}

void Main() {

    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);

    int lastPB = 0;
    int delay = 1000;
    int retries = 5;
    string lastMapId = "";
    bool requestRequired = false;

    while(true) {
        sleep(delay);

        if (!enabled) {
            continue;
        }

        auto map = app.RootMap;
        if (map is null || map.MapInfo.MapUid == "") {
            lastMapId = "";
            continue;
        }

        bool newMap = lastMapId != map.MapInfo.MapUid;
        lastMapId = map.MapInfo.MapUid;

        int time = -1;
        if(network.ClientManiaAppPlayground !is null) {
			auto userMgr = network.ClientManiaAppPlayground.UserMgr;
			MwId userId;
			if (userMgr.Users.Length > 0) {
				userId = userMgr.Users[0].Id;
			} else {
				userId.Value = uint(-1);
			}
			
			auto scoreMgr = network.ClientManiaAppPlayground.ScoreMgr;
			time = scoreMgr.Map_GetRecord_v2(userId, map.MapInfo.MapUid, "PersonalBest", "", "TimeAttack", "");			
        }

        if (newMap) {
            if (debug) {
                print("New Map");
            }
            lastPB = time;
        }
        
        if (time != -1 && time != lastPB) {
            requestRequired = true;
            retries = 5;
        }

        if (requestRequired && retries > 0) {
            if (debug) {
                print("New PB time");
            }
            Json::Value data = Json::Object();
            data["time"] = time;
            data["channel"] = channel;
            data["password"] = password;
            auto result = PostAsync(data);
            auto resultCode = result.ResponseCode();

            if (resultCode == 200) {
                if (debug) {
                    print("Successfully sent PB to server.");
                }
                
                requestRequired = false;
                lastPB = time;
                retries = 5;
            } else {
                
                if (debug) {
                    print(resultCode);
                    print("Problem while sending the PB to the server.");
                }
                requestRequired = true;
                retries = retries - 1;
                sleep(10000);
            }
        }

    }

}
