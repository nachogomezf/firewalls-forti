import json
import numpy as np

# 1 - Leer ambos ficheros
def read_file(filename):
    with open(filename, 'r') as file:
        data = json.load(file)
    return data

# Function to write data to a file in JSON format
def write_file(filename, data):
    with open(filename, "w", encoding='utf-8') as out_file:
        json_obj1 = out_file.write(json.dumps(data, indent=4, ensure_ascii=False))

# 2 - Hacer comparaciones -> orden: addresses, addrgrps, services y policies
def compare(data, data_objective, name):

    data = data[name]
    data_objective = data_objective[name]

    no_estan = []
    quitar = []
    
    for elem in data:
        if elem not in data_objective:
            quitar.append(elem)   # Mostrar las addresses que hay que quitar

    for elem in data_objective:
        if elem not in data:
            no_estan.append(elem) # Mostrar las addresses que hay que meter

    dict_save = {
        "add": no_estan,
        "delete": quitar
    }
    #write_file("data/output/" + name + ".json", {name: dict_save})

    return {name: dict_save}

############################### MAIN ###############################
if __name__ == "__main__":

    #Leer ficheros json
    #file_data = "data/output.json"
    # file_data = "data/output_test.json"
    file_data = "data/output/firewall_info.json"
    file_objective = "references/pols_type_I.json"
    # file_objective = "references/test.json"

    data = read_file(filename=file_data)
    data_objective = read_file(filename=file_objective)
    # print(data)
    elems = list(data.keys())   # Array con todos los nombres de los elementos que tenemos que comparar
    output = []     # Array con el resultado final de todas las comparaciones

    for name in elems:
        output.append(compare(data=data, data_objective=data_objective, name=name))

    write_file("data/output/comparation.json", {
        list(output[0].keys())[0]: output[0][list(output[0].keys())[0]],
        list(output[1].keys())[0]: output[1][list(output[1].keys())[0]],
        list(output[2].keys())[0]: output[2][list(output[2].keys())[0]],
        list(output[3].keys())[0]: output[3][list(output[3].keys())[0]]
    })
