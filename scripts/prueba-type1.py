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


#################################
#################################
#################################

def clean_politics2(filename, vdom_info):
    data_politics = read_file(filename=filename)
    data_politics = data_politics["politicas"]

    add_list = data_politics["add"]
    delete_list = data_politics["delete"]

    # vdom_info -> vdom e interfaces

    new_politics_add = []
    new_politics_delete = []

### Explicación ####
# Miramos los elementos que hay que añadir
# Comprobamos que el vdom de la política lo tenga nuestro firewall
# Comprobamos que las interfaces de origen y destino de la política estén definidos en el VDOm de nuestro firewall
# También puede darse el caso de que la interfaz origen o destino sea any.
# En caso de que se cumpla se añade a la lista

# Si el VDOM es WAN se añade directamente la política
####################

    for elem in add_list:
        for vdom_individual in vdom_info:
            if(elem["VDOM"] == "WAN"):
                new_politics_add.append(elem)
                break  # Sino se guarda por cada iteración de vdom
            elif(elem["VDOM"] == vdom_individual["vdom_name"]):
                srcint_lower = elem['srcint'].lower()
                dstint_lower = elem['dstint'].lower()
                if (srcint_lower == 'any' or dstint_lower == 'any') or (elem['srcint'] in vdom_individual["interfaces"] and elem['dstint'] in vdom_individual["interfaces"] ):
                    new_politics_add.append(elem)                


### Explicación
# Pienso que solo habría que comprobar las de ADD si realmente están esas interfaces en esos VDOM.
# Las de delete, son políticas que están y no deberían de estar. Por eso no habría que hacer más comrpobaciones.


    new_politics_delete = delete_list

    return new_politics_add, new_politics_delete



#######################################################################################################
#######################################################################################################
#######################################################################################################


if __name__ == "__main__":

    config_FWs_data = read_file("references/config_FWs.json")
    vdoms_general, vdom_names = get_VDOMS(config_FWs_data)

    info_vdoms = [] # Info de los VDOM { "vdom_name: nombre, "interfaces": array interfaces }

    vdom_names_list = []

    for vdom in vdom_names:
        ifs = get_interfaces_by_VDOM(vdom, vdoms_general)
        info = {
            "vdom_name": vdom,
            "interfaces": ifs
        }
        vdom_names_list.append(vdom)
        info_vdoms.append(info)

    policies_data = read_file("references/pols_type_I.json")
    policies_data = policies_data["politicas"]


# Comprobamos las interfaces y las políticas a la vez.

    new_politics_add, new_politics_delete = clean_politics2(filename="data/output/comparation.json", vdom_info=info_vdoms)

    write_file("data/output/comparation_v2.json", {
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
        writer.writerow(["VDOM", "srcint", "dstint", "SRC", "DST","SVC", "ACTION"])
        for politica in new_politics_add:
            writer.writerow([politica["VDOM"], politica["srcint"], politica["dstint"], politica["SRC"],politica["DST"],politica["SVC"],politica["ACTION"]])

    with open(csv_delete, mode="w", newline="") as archivo_csv:
        # Crear un objeto writer para escribir en el archivo
        writer = csv.writer(archivo_csv)
        # Escribir una fila con los encabezados
        writer.writerow(["VDOM", "srcint", "dstint", "SRC", "DST", "SVC", "ACTION"])

        for politica in new_politics_delete:
            if("SVC" in politica.keys()):
                writer.writerow([politica["VDOM"], politica["srcint"], politica["dstint"], politica["SRC"],politica["DST"],politica["SVC"],politica["ACTION"]])
            else:
                writer.writerow([politica["VDOM"], politica["srcint"], politica["dstint"], politica["SRC"],politica["DST"],"",politica["ACTION"]])

            