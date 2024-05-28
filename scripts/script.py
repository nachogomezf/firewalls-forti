import requests
import json

# Function to send GET request and return the response
def get_data(url):
    response = requests.get(url, verify=False)

    if response.status_code != 200:
        print(f"Request failed with status code {response.status_code}")

    return response

# Function to write data to a file in JSON format
def write_file(filename, data):
    with open(filename, "w", encoding='utf-8') as out_file:
        json_obj1 = out_file.write(json.dumps(data, indent=4, ensure_ascii=False))

# Function to get addresses from the API and return a list of address data
def get_addresses(vdom_name, data):
    url_addr = "https://%s/api/v2/cmdb/firewall/%s?vdom=%s&access_token=%s" % (data["ip"], "address", vdom_name, data["token"])
    addresses = get_data(url=url_addr).json()["results"]
    print(url_addr)

    list_addresses = []

    for i, elem in enumerate(addresses):

        control = False

        nombre = addresses[i]["name"]
        tipo = addresses[i]["type"]

        #If address has the field "subnet":
        if "subnet" in addresses[i]:
            red = addresses[i]["subnet"]

            # if existe en el array global -> añadir unicamente el vdom
            for elem in list_addresses:
                if elem["nombre"] == nombre and elem["red"] == red:
                    elem["vdom"] += "," + vdom_name
                    control = True

            if not control:
                addr_data = {"nombre": nombre, "tipo": tipo, "red": red, "vdom": vdom_name}
                list_addresses.append(addr_data)

        else: continue

    return list_addresses

# Function to get address groups from the API and return a list of address group data
def get_addrgrps(vdom_name, data):
    url_addrgrp = "https://%s/api/v2/cmdb/firewall/%s?vdom=%s&access_token=%s" % (data["ip"], "addrgrp", vdom_name, data["token"])
    addrgrps = get_data(url=url_addrgrp).json()["results"]

    list_grps = []

    for i, elem in enumerate(addrgrps):

        nombre = addrgrps[i]["name"]
        member = ""

        for grp in addrgrps[i]["member"]:
            if member == "":
                member = grp["name"]
            else:
                member += "," + grp["name"]


        list_grps.append({"nombre": nombre, "members": member, "vdom": vdom_name })

    return list_grps

############################################################################################################
#                       MAIN CODE
############################################################################################################

if __name__ == "__main__":

    with open("data/info/vars_globales.json") as json_file:
        data = json.load(json_file)

    url_vdoms = "https://%s/api/v2/cmdb/system/vdom/?access_token=%s" % (data["ip"],data["token"])
    vdoms = get_data(url=url_vdoms).json()["results"]

    write_file("data/vdom.json", vdoms)

    list_addresses = []

    for vdom in vdoms:

        vdom_name = vdom["name"]

        list_addresses = get_addresses(vdom_name=vdom_name, data=data)
        #list_addresses.append(get_addresses(vdom_name=vdom_name, data=data))
        list_grps = get_addrgrps(vdom_name=vdom_name, data=data)

        url_policies = "https://%s/api/v2/cmdb/firewall/%s?access_token=%s" % (data["ip"], "policy", data["token"])
        policies = get_data(url=url_policies).json()["results"]

        list_policies = []

        for policy in policies:

            srcint = policy["srcintf"][0]['name']
            dstint = policy["dstintf"][0]['name']
            src = policy["srcaddr"][0]["name"]
            dst = policy["dstaddr"][0]["name"]
            svc = policy["service"][0]['name']
            action = policy["action"]

            item = {"VDOM": vdom_name, "srcint": srcint, "dstint": dstint, "SRC": src, "DST": dst, "ACTION": action}

            list_policies.append(item)

    url_services = "https://%s/api/v2/cmdb/firewall.service/custom/?access_token=%s" % (data["ip"],data["token"])

    services = get_data(url=url_services).json()["results"]
    list_svcs = []

    for elem in services:
        nombre = elem["name"]
        category = elem["category"]
        protocol = elem["protocol"]

        svc = {"nombre": nombre, "category": category, "protocol": protocol}

        if "tcp-portrange" in elem.keys():
            if elem["tcp-portrange"] != "":
                tcpportrange = elem["tcp-portrange"]
                svc["tcpportrange"] = tcpportrange
        
        if "udp-portrange" in elem.keys():
            if elem["udp-portrange"] != "":
                udpportrange = elem["udp-portrange"]
                svc["udpportrange"] = udpportrange
        
        list_svcs.append(svc)

    #Save the outputs in different files
   
    write_file("data/output/firewall_info.json", {"address": list_addresses, "addrgrp": list_grps, "svcs": list_svcs, "politicas":list_policies})

    #https://github.com/vladimirs-git/fortigate-api/blob/main/fortigate_api/service.py