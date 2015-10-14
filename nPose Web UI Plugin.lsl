#define DOPOSE 200
#define DOBUTTON 207
#define WEB_UI_CHAN -585357440
#define SET_PREFIX "SET"
#define BTN_PREFIX "BTN"
#define DEFAULT_PREFIX "DEFAULT"
#define UI_URL "http://ui.npose.org/"

string url;

integer randInt(integer n)
{
     return (integer)llFrand(n + 1);
}

string  RandomString(integer length)
{
    string characters = "abcdefghijklmnopqrstuvwxyz";
    string emp;
    integer p;
    integer q;
    do
    {
       q = (integer) llFrand(26);
       emp += llGetSubString(characters, q, q);
    }
    while(++p < length);                                                    
    return emp;
}

string secretKey;

string getSignature(string secret, key av) {
    string combined = secret + ":" + (string)av;
    string sig =  llSHA1String(combined);
    return sig;
}

string getApiUrl(list path,  key av) {
    string apiUrl = url + "/";
    apiUrl += llDumpList2String(path, "/");
    if (llGetListLength(path)) {
        apiUrl += "/";
    }
    apiUrl += "?av=" + (string)av;
    apiUrl += "&sig=" + getSignature(secretKey, av);
    return apiUrl;
}

string getUiUrl(list path, key av) {
    return UI_URL + "?api_url=" + llEscapeURL(getApiUrl(path, av));
}

string poseJSON(list menuPath) {
    // menuPath will be a list of folders and subfolders.  only cards in the inner-most subfolder will 
    // be returned from this function.
    integer ncCount = llGetInventoryNumber(INVENTORY_NOTECARD);
    integer n;
    string json = "[";
    integer first = TRUE;
    list usedNames = [];
    
    // loop in reverse order so we're sure to get child cards before parents.
    // otherwise the hasChildren check won't be accurate.
    for (n=ncCount - 1; n >= 0 ; n--) {
        string ncName = llGetInventoryName(INVENTORY_NOTECARD, n);
        // throw away any perms parts for now.  we don't care.
        integer permsIdx = llSubStringIndex(ncName,"{");
        if (~permsIdx) {
            ncName = llGetSubString(ncName, 0, permsIdx - 1);
        } 
        
        list pathParts = llParseStringKeepNulls(ncName, [":"], []);
        string prefix = llList2String(pathParts, 0);
        if (prefix != SET_PREFIX && prefix != DEFAULT_PREFIX && prefix != BTN_PREFIX) {
            jump continue;
        }
        
        // throw away prefix now
        pathParts = llList2List(pathParts, 1, -1);
        // we have a pose card.  Now see if it's at our level
        if (llListFindList(pathParts, menuPath) != 0) {
           jump continue;
        }
                
        string itemName = llList2String(pathParts, llGetListLength(menuPath)); // short name of item within this folder
        if (llListFindList(usedNames, [itemName]) == -1) {
            usedNames += itemName;
        } else {
            jump continue;
        }
        
        string hasChildren = "false";

        if (llGetListLength(pathParts) > llGetListLength(menuPath) + 1) {
            hasChildren = "true";
        }
        
        // If we get here, then we know that itemName is an item that is at our level of the menu, 
        // and not already included in the menu.  Also, pathParts is a list of all the parent folders
        string thumbName = llDumpList2String(["THUMB"] + menuPath + itemName, ":");
        string thumbKey = ""; // image uuid
        if (llGetInventoryType(thumbName) == INVENTORY_TEXTURE) {
            thumbKey = (string)llGetInventoryKey(thumbName);
        }
        
        string jsonItem = "";
        // build up JSON
        if (llSubStringIndex(ncName, prefix) == 0) {
            if (first) {
                first = FALSE;
            } else {
                json += ",";
            }
            json += "{";
            json += "\"name\":\"" + itemName + "\"";
            json += ",\"hasChildren\":" + hasChildren; 
            if (thumbKey != "") {
                json += ",\"thumb\":\"" + thumbKey + "\"";                 
            }
            json += "}";
        }                   
        // I miss Python's "continue" statement for early termination of a single loop iteration.
        // It's nice not to nest 10 levels deep when you have 10 conditionals in your code.
        // So let's emulate it with a jump.
        @continue;
    }
    
    json += "]";
    return json;
}

list SeatedAvs(){
    list avs = [];
    integer n = llGetNumberOfPrims();
    for(; n >= llGetObjectPrimCount(llGetKey()); --n) {
        //only check link numbers greater than the number of actual prims, these will be the AV link numbers.
        key id = llGetLinkKey(n);
        if(llGetAgentSize(id) != ZERO_VECTOR) {
            avs = [id] + avs;
        }
    }
    return avs;
}

handleRequest(key id, key av, string path, string callback) {
    list pathParts = llParseString2List(path, ["/"], []);
    // handle root case
    if (llGetListLength(pathParts) == 0) {
        pathParts = [];
    }
    string setName = llDumpList2String(SET_PREFIX + pathParts, ":");
    string defaultName = llDumpList2String(DEFAULT_PREFIX + pathParts, ":");
    string buttonName = llDumpList2String(BTN_PREFIX + pathParts, ":");    

    if(llGetInventoryType(defaultName) == INVENTORY_NOTECARD) {
        llMessageLinked(LINK_SET, DOPOSE, defaultName, id);                    
    }
    if(llGetInventoryType(setName) == INVENTORY_NOTECARD) {
        llMessageLinked(LINK_SET, DOPOSE, setName, id);
    }
    if(llGetInventoryType(buttonName) == INVENTORY_NOTECARD) {
        llMessageLinked(LINK_SET, DOBUTTON, buttonName, id);
    }    
    string out = callback + "(" + poseJSON(pathParts) + ");";
    llHTTPResponse(id, 200, out);
}

handleForbidden(key id, string msg) {
    llHTTPResponse(id, 401, msg);
}

loadMenu(key av) {
    llLoadURL(av, "Menu", getUiUrl([], av));
}

default
{
    on_rez(integer param) {
        llResetScript();
    }
    
    changed(integer change) {
        if (change & (CHANGED_OWNER | CHANGED_REGION | CHANGED_REGION_START)) {
            llResetScript();
        }
    }
    
    state_entry() {
        // llSay(0,poseJSON(["Meditate"]));
        secretKey = RandomString(32);
        llRequestURL();
    }
    
    http_request (key id, string method, string body) {
        if (method == URL_REQUEST_DENIED) {
            llOwnerSay("URL request denied");
        } else if (method == URL_REQUEST_GRANTED) {
            url = body;
        } else if (method == "GET") {
            string qs = llGetHTTPHeader(id, "x-query-string");
            string path = llGetHTTPHeader(id, "x-path-info");
            list split = llParseStringKeepNulls(qs, ["&"], []);
            integer n;
            integer stop = llGetListLength(split);
            key av;
            string sig;
            string callback;
            for(n=0; n < stop; n ++) {
                list tokval = llParseStringKeepNulls(llList2String(split, n), ["="], []);
                
                string tok = llUnescapeURL(llList2String(tokval, 0));
                string val = llUnescapeURL(llList2String(tokval, 1));
                if (tok == "av") {
                    av = (key)val;
                } else if (tok == "sig") {
                    // remove trailing slash if present
                    integer trailingSlash = llSubStringIndex(val, "/");
                    if (~trailingSlash) {
                        val = llDeleteSubString(val, trailingSlash, trailingSlash);
                    }
                    sig = val;
                } else if (tok == "callback") {
                    callback = val;
                }
            }
            // check signature
            if (sig != getSignature(secretKey, av)) {
                return handleForbidden(id, "Invalid signature.");
            }
            
            // check that the av is seated on the object
            if (!(~llListFindList(SeatedAvs(), [av]))) {
                return handleForbidden(id, "You are not seated on the object.");
            }
            
            handleRequest(id, av, path, callback);
        }
        @end;
    }

    link_message(integer source, integer num, string str, key id) {
        if (num == WEB_UI_CHAN) {
            loadMenu(id);
        }
    }
}

