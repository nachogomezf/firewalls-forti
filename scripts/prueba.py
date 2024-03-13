import json
import numpy as np
import csv

# 1 - Leer ambos ficheros
def read_file(filename):
    with open(filename, 'r') as file:
        data = json.load(file)
    return data

# Function to write data to a file in JSON format
def write_file(filename, data):
    with open(filename, "w", encoding='utf-8') as out_file:
        json_obj1 = out_file.write(json.dumps(data, indent=4, ensure_ascii=False))

def get_VDOMS(data):

    general_data = data["FWS"]
    general_data = general_data[0]
    vdoms_general = general_data["VDOM"]

    vdom_names = []

    for elem in vdoms_general:
        vdom_names.append(elem["nombre"])

    return vdoms_general, vdom_names

def get_interfaces_by_VDOM(VDOM, vdom_data):
    
    result = []

    for vdom in vdom_data:
        if vdom["nombre"] == VDOM:
            interfaces = vdom["ifs"]
            for interfaz in interfaces:
                result.append(interfaz["nombre"])

    return result

def check_interfaces(vdom_info, policies):

    vdom_results = []

    for interfaz in vdom_info["interfaces"]:
        for policy in policies:
            srcint = policy["srcint"]
            if interfaz == srcint:
                if policy["dstint"] in vdom_info["interfaces"]:
                    vdom_results.append({
                        "srcint": srcint,
                        "dstint": policy["dstint"]
                    })

    return vdom_results

def get_interfaces(vdom_info, name):
    result = []

    for elem in vdom_info:
        if elem["vdom_name"] == name:
            result = elem["interfaces"]

    return result

def clean_politics(filename, vdom_info):
    data_politics = read_file(filename=filename)
    data_politics = data_politics["politicas"]

    add_list = data_politics["add"]
    delete_list = data_politics["delete"]

    new_politics_add = []
    new_politics_delete = []

    for elem in add_list:
        interfaces = get_interfaces(vdom_info=vdom_info, name=elem['VDOM'])
        srcint_lower = elem['srcint'].lower()
        dstint_lower = elem['dstint'].lower()
        if srcint_lower == 'any' or dstint_lower == 'any' or (elem['srcint'] in interfaces and elem['dstint'] in interfaces):
            new_politics_add.append(elem)


    for elem in delete_list:
        interfaces = get_interfaces(vdom_info=vdom_info, name=elem['VDOM'])
        if elem['srcint'] in interfaces and elem['dstint'] in interfaces:
            new_politics_delete.append(elem)

    return new_politics_add, new_politics_delete

if __name__ == "__main__":

    config_FWs_data = read_file("references/config_FWs.json")
    vdoms_general, vdom_names = get_VDOMS(config_FWs_data)

    info_vdoms = [] # Info de los VDOM { "vdom_name: nombre, "interfaces": array interfaces }

    for vdom in vdom_names:
        ifs = get_interfaces_by_VDOM(vdom, vdoms_general)
        info = {
            "vdom_name": vdom,
            "interfaces": ifs
        }
        info_vdoms.append(info)

    policies_data = read_file("references/pols_type_I.json")
    policies_data = policies_data["politicas"]

    vdom_info = []

    for vdom in info_vdoms:
        if vdom["vdom_name"] != "WAN":
            info = check_interfaces(vdom_info=vdom, policies=policies_data)
            
            for elem in info:
                vdom_info.append({
                    "VDOM": vdom["vdom_name"],
                    "srcint": elem["srcint"],
                    "dstint": elem["dstint"]
                })

    for elem in policies_data:
        if elem["VDOM"] == "WAN":
            vdom_info.append({
                "VDOM": "WAN",
                "srcint": elem["srcint"],
                "dstint": elem["dstint"]
            })

    json_output = {
        "politicas": vdom_info
    }

    write_file("data/test/test.json", json_output)

    file_data = read_file(filename="data/output/comparation.json")
    new_politics_add, new_politics_delete = clean_politics(filename="data/output/comparation.json", vdom_info=info_vdoms)

    write_file("data/output/comparation_v2.json", {
        "address": file_data['address'],
        "addrgrp": file_data['addrgrp'],
        "svcs": file_data['svcs'],
        "politicas": {
            "add": new_politics_add,
            "delete": new_politics_delete
        }
    })

    csv_add = "data/output/politicas_add.csv"
    csv_delete = "data/output/politicas_delete.csv"
    # Abrir el archivo CSV en modo escritura
    with open(csv_add, mode="w", newline="") as archivo_csv:
        # Crear un objeto writer para escribir en el archivo
        writer = csv.writer(archivo_csv)
        # Escribir una fila con los encabezados
        writer.writerow(["VDOM", "srcint", "dstint", "SRC", "DST", "ACTION"])
        for politica in new_politics_add:
            writer.writerow([politica["VDOM"], politica["srcint"], politica["dstint"], politica["SRC"],politica["DST"],politica["SVC"],politica["ACTION"]])

    with open(csv_delete, mode="w", newline="") as archivo_csv:
        # Crear un objeto writer para escribir en el archivo
        writer = csv.writer(archivo_csv)
        # Escribir una fila con los encabezados
        writer.writerow(["VDOM", "srcint", "dstint", "SRC", "DST", "SVC", "ACTION"])

        for politica in new_politics_delete:
            writer.writerow([politica["VDOM"], politica["srcint"], politica["dstint"], politica["SRC"],politica["DST"],politica["SVC"],politica["ACTION"]])
